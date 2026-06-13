`ifndef AXI4_VIRTUAL_WRITE_MISS_THEN_READ_EVICTION_SEQ_INCLUDED_
`define AXI4_VIRTUAL_WRITE_MISS_THEN_READ_EVICTION_SEQ_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_virtual_write_miss_then_read_eviction_seq
//
// Scenario (5 masters, same cache set index=0):
//   Master 0  WRITE miss  tag=0  addr=0x0000_0001  → way=0 filled+dirty  (B waited)
//   Master 1  WRITE miss  tag=1  addr=0x0000_0401  → way=1 filled+dirty  (B waited)
//   Master 2  WRITE miss  tag=2  addr=0x0000_0801  → way=2 filled+dirty  (B waited)
//   Master 3  WRITE miss  tag=3  addr=0x0000_0C01  → way=3 filled+dirty  (B waited)
//   Master 4  READ  miss  tag=4  addr=0x0000_1001  → all 4 ways valid+dirty
//                                                  → LRU victim evicted (writeback)
//                                                  → new line refilled
//                                                  → read data returned
//
// Each write is serialised (start() blocks until B response) before the next.
// At the time of the read allocation zero MSHRs are in-flight, so
// find_victim_way does a clean LRU scan across all 4 ways.
//--------------------------------------------------------------------------------------------
class axi4_virtual_write_miss_then_read_eviction_seq extends axi4_virtual_base_seq;
  `uvm_object_utils(axi4_virtual_write_miss_then_read_eviction_seq)

  axi4_master_write_miss_seq  m_wr_miss_seq [4];
  axi4_master_read_miss_seq   m_rd_miss_seq;

  axi4_slave_writeback_seq    s_wb_seq     [NO_OF_SLAVES];
  axi4_slave_refill_seq       s_refill_seq [NO_OF_SLAVES];

  function new(string name = "axi4_virtual_write_miss_then_read_eviction_seq");
    super.new(name);
  endfunction

  task body();
    super.body();

    `uvm_info(get_type_name(),
      "STARTING: 4xWRITE-MISS FILL ALL WAYS DIRTY -> READ-MISS LRU EVICTION", UVM_LOW)

    fork

      // ----------------------------------------------------------------
      // THREAD 1 — SLAVE BACKGROUND LOOPS (identical to existing vseq)
      // ----------------------------------------------------------------
      begin
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
          automatic int slv = s;

          s_wb_seq[slv]     = axi4_slave_writeback_seq::type_id::create(
                                $sformatf("s_wb_seq[%0d]",     slv));
          s_refill_seq[slv] = axi4_slave_refill_seq::type_id::create(
                                $sformatf("s_refill_seq[%0d]", slv));

          fork
            forever s_wb_seq[slv].start(
                      p_sequencer.axi4_slave_write_seqr_h[slv]);
            forever s_refill_seq[slv].start(
                      p_sequencer.axi4_slave_read_seqr_h[slv]);
          join_none
        end
      end

      // ----------------------------------------------------------------
      // THREAD 2 — MASTER TRANSACTIONS
      // ----------------------------------------------------------------
      begin

        // ── PHASE 1: Masters 0-3 sequential write misses ─────────────
        // Each start() blocks until B response — MSHR fully retired
        // before next write issues.  After all four: ways 0-3 valid+dirty.
        `uvm_info(get_type_name(),
          "PHASE 1: Masters 0-3 sequential write misses — filling all ways dirty", UVM_LOW)

        for (int m = 0; m < 4; m++) begin
          automatic int local_m = m;

          m_wr_miss_seq[local_m] = axi4_master_write_miss_seq::type_id::create(
                                     $sformatf("m_wr_miss_seq[%0d]", local_m));
          m_wr_miss_seq[local_m].txn_addr = (32'(local_m) << 10) | 32'h1;
          m_wr_miss_seq[local_m].txn_num  = local_m;

          m_wr_miss_seq[local_m].start(
            p_sequencer.axi4_master_write_seqr_h[local_m]);

          `uvm_info(get_type_name(),
            $sformatf("DONE PHASE1 WRITE MISS M[%0d] addr=0x%0h — way%0d now dirty",
                       local_m, m_wr_miss_seq[local_m].txn_addr, local_m),
            UVM_LOW)
        end

        // ── PHASE 2: Master 4 — read miss to tag=4 ───────────────────
        // All 4 ways valid+dirty, no in-flight MSHRs.
        // Clean LRU scan → evict LRU dirty way → writeback + refill.
        `uvm_info(get_type_name(),
          "PHASE 2: Master 4 read miss tag=4 addr=0x1001 -> LRU eviction of dirty way",
          UVM_LOW)

        m_rd_miss_seq = axi4_master_read_miss_seq::type_id::create("m_rd_miss_seq");
        m_rd_miss_seq.txn_addr = 32'h0000_1001;
        m_rd_miss_seq.txn_num  = 4;

        m_rd_miss_seq.start(p_sequencer.axi4_master_read_seqr_h[4]);

        `uvm_info(get_type_name(),
          $sformatf("DONE PHASE2 READ MISS M[4] addr=0x%0h — dirty way evicted, new line filled",
                     m_rd_miss_seq.txn_addr),
          UVM_LOW)

      end // Thread 2

    join

    `uvm_info(get_type_name(),
      "COMPLETE: 4xWRITE-MISS then READ-MISS EVICTION TEST", UVM_LOW)

  endtask

endclass

`endif
