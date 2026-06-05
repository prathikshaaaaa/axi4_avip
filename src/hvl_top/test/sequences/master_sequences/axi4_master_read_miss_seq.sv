`ifndef AXI4_MASTER_READ_MISS_SEQ_INCLUDED_
`define AXI4_MASTER_READ_MISS_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_master_read_miss_seq
//
// Purpose:
//   Drives a single INCR-4 READ transaction to a cache-miss address on behalf
//   of one master.  The virtual sequence sets txn_addr / txn_num before calling
//   start(), so every master in the fork targets a unique cache-line tag and
//   the same cache set — matching the read-miss / eviction address scheme.
//
// Address scheme (set by axi4_virtual_read_miss_seq):
//   txn_addr = (txn_num << 10) | 32'h1
//   Bits[ 3: 0] — byte offset  (4-beat × 4-byte line → 4 word-offset bits)
//   Bits[ 9: 4] — set index    (all 0 → every read hits the same set)
//   Bits[31:10] — tag          (unique per txn_num → each read brings a new line)
//
// Cache scenario:
//   TXN 0-3 → cold-miss per way (cache set had <4 valid lines)
//             slave refill_seq supplies the cache-line data on the R channel
//   TXN 4   → all 4 ways occupied → eviction of dirty way
//             slave writeback_seq drains the dirty write-back on the W channel
//             slave refill_seq   supplies the new line on the R channel
//--------------------------------------------------------------------------------------------
class axi4_master_read_miss_seq extends axi4_master_base_seq;
  `uvm_object_utils(axi4_master_read_miss_seq)

  // Set by the virtual sequence before start() is called
  logic [31:0] txn_addr;
  int          txn_num;

  function new(string name = "axi4_master_read_miss_seq");
    super.new(name);
  endfunction

  task body();

    req = axi4_master_tx::type_id::create("req");

    start_item(req);

    if (!req.randomize() with {
      // ── Transaction type ──────────────────────────────────────────────
      req.tx_type       == READ;
      req.transfer_type == NON_OUTSTANDING_READ;

      // ── AR-channel burst attributes ───────────────────────────────────
      req.arburst == READ_INCR;            // incremental burst
      req.arsize  == READ_4_BYTES;         // 32-bit data bus
      req.arlen   == 3;                    // 4 beats = one full cache line
                                           // (WORDS_PER_LINE - 1)

      // ── Cache attributes ──────────────────────────────────────────────
      // READ_WRITE_ALLOCATE = read-allocate + write-allocate
      // Tells the cache controller to allocate on this read miss
      req.arcache == READ_ALLOCATE;

      // ── Address — supplied by virtual sequence ────────────────────────
      req.araddr == txn_addr;

    }) begin
      `uvm_fatal(get_type_name(),
        $sformatf("Randomization failed: txn_num=%0d addr=0x%0h",
                   txn_num, txn_addr))
    end

    finish_item(req);

    `uvm_info(get_type_name(),
      $sformatf("READ MISS TXN[%0d] araddr=0x%0h arlen=%0d [%0s]",
                txn_num,
                req.araddr,
                req.arlen,
                (txn_num < 4) ? "COLD MISS / REFILL" : "EVICTION + REFILL"),
      UVM_LOW)

  endtask

endclass

`endif
