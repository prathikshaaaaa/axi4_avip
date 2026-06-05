`ifndef AXI4_VIRTUAL_READ_MISS_SEQ_INCLUDED_
`define AXI4_VIRTUAL_READ_MISS_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_virtual_read_miss_seq
//
// Purpose:
//   Orchestrates a multi-master READ-MISS stress scenario.
//   The sequence structure is intentionally identical to axi4_virtual_writeback_seq
//   (which tests write-miss / writeback), with the single change that masters
//   are driven on the READ sequencer with axi4_master_read_miss_seq.
//
// Slave sequences (reused unchanged):
//   axi4_slave_writeback_seq  — runs forever on axi4_slave_write_seqr_h[]
//                               services any dirty-line evictions that the cache
//                               controller issues on the AW/W channels
//   axi4_slave_refill_seq     — runs forever on axi4_slave_read_seqr_h[]
//                               services cache-line fetches on the AR/R channels
//
// Master sequence:
//   axi4_master_read_miss_seq — one READ per master, targeting a unique tag
//                               so every read creates a cache miss
//
// Address scheme per master m (txn_num = m):
//   araddr = (m << 10) | 32'h1
//   Bits[ 3: 0] = byte offset  (4-beat × 4-byte → 4 offset bits)
//   Bits[ 9: 4] = set index    (all 0 → all reads hit the same cache set)
//   Bits[31:10] = tag          (unique per m → each read is a different tag)
//
//   M0 (txn_num=0) araddr=0x0000_0001  → tag 0 → cold miss → way0 filled
//   M1 (txn_num=1) araddr=0x0000_0401  → tag 1 → cold miss → way1 filled
//   M2 (txn_num=2) araddr=0x0000_0801  → tag 2 → cold miss → way2 filled
//   M3 (txn_num=3) araddr=0x0000_0C01  → tag 3 → cold miss → way3 filled
//   M4 (txn_num=4) araddr=0x0000_1001  → tag 4 → set full  → eviction + refill
//
// Execution model (mirrors axi4_virtual_writeback_seq exactly):
//   fork
//     Thread-1: spawn slave forever-loops with join_none, then exit
//     Thread-2: spawn master sequences with join_none, then wait fork
//   join
//   → Thread-2's wait fork sees ONLY the master threads, not the slave loops.
//   → When all masters complete, the join fires and the test ends cleanly.
//--------------------------------------------------------------------------------------------
class axi4_virtual_read_miss_seq extends axi4_virtual_base_seq;
  `uvm_object_utils(axi4_virtual_read_miss_seq)

  // ── Sequence handles ────────────────────────────────────────────────────
  axi4_master_read_miss_seq  m_rd_miss_seq  [NO_OF_MASTERS];

  // Slave sequences are identical to the write-miss / writeback test:
  // the cache controller still needs a write-back path and a refill path
  // regardless of whether the initiating transaction was a read or a write.
  axi4_slave_writeback_seq   s_wb_seq       [NO_OF_SLAVES];
  axi4_slave_refill_seq      s_refill_seq   [NO_OF_SLAVES];

  function new(string name = "axi4_virtual_read_miss_seq");
    super.new(name);
  endfunction

  task body();

    // Grab env config + cast p_sequencer (done in parent body())
    super.body();

    `uvm_info(get_type_name(), "STARTING READ-MISS TEST", UVM_LOW)

    fork

      // ----------------------------------------------------------------
      // THREAD 1 — SLAVE BACKGROUND THREADS
      //
      // Spawn one writeback-forever and one refill-forever per slave,
      // then let this thread exit.  The join_none children keep running
      // until the simulation ends (or the test object is killed).
      // ----------------------------------------------------------------
      begin
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
          automatic int slv_idx = s;

          s_wb_seq[s]     = axi4_slave_writeback_seq::type_id::create(
                              $sformatf("s_wb_seq[%0d]",     s));
          s_refill_seq[s] = axi4_slave_refill_seq::type_id::create(
                              $sformatf("s_refill_seq[%0d]", s));

          fork
            // Writeback channel — drains dirty evictions from the cache
            forever s_wb_seq[slv_idx].start(
                      p_sequencer.axi4_slave_write_seqr_h[slv_idx]);

            // Refill channel — supplies cache-line data back to the master
            forever s_refill_seq[slv_idx].start(
                      p_sequencer.axi4_slave_read_seqr_h[slv_idx]);
          join_none
        end
      end // Thread 1

      // ----------------------------------------------------------------
      // THREAD 2 — MASTER READ-MISS THREADS
      //
      // Each master gets a unique txn_num → unique tag → unique cache-miss.
      // All masters fire in parallel; wait fork here scopes only to the
      // join_none children created inside this begin…end block, so it
      // does NOT wait for the slave forever-loops above.
      // ----------------------------------------------------------------
      begin
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
          automatic int local_m   = m;
          automatic int local_num = m;

          m_rd_miss_seq[m] = axi4_master_read_miss_seq::type_id::create(
                               $sformatf("m_rd_miss_seq[%0d]", m));

          // Address: unique tag per master, same set (index=0)
          m_rd_miss_seq[m].txn_addr = (logic[31:0]'(local_num) << 10) | 32'h1;
          m_rd_miss_seq[m].txn_num  = local_num;

          fork
            begin
              // Fire on the READ sequencer (not the write sequencer)
              m_rd_miss_seq[local_m].start(
                p_sequencer.axi4_master_read_seqr_h[local_m]);

              `uvm_info(get_type_name(),
                $sformatf("DONE READ MISS TXN[%0d] M[%0d] araddr=0x%0h",
                           local_num, local_m,
                           m_rd_miss_seq[local_m].txn_addr),
                UVM_LOW)
            end
          join_none
        end

        // Wait for every master to finish; slave loops are excluded
        wait fork;
      end // Thread 2

    join // outer fork

    `uvm_info(get_type_name(), "READ-MISS TEST COMPLETE", UVM_LOW)

  endtask

endclass

`endif
