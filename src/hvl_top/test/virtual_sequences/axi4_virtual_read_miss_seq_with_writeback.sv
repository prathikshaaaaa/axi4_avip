`ifndef AXI4_VIRTUAL_READ_MISS_SEQ_WITH_WRITEBACK_INCLUDED_
`define AXI4_VIRTUAL_READ_MISS_SEQ_WITH_WRITEBACK_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_virtual_read_miss_seq_with_writeback
// Scenario (5 masters, same cache set index=0):
//   Master 0  READ  miss  tag=0  addr=0x0000_0001  → cold miss → way0 filled (clean)
//   Master 1  READ  miss  tag=1  addr=0x0000_0401  → cold miss → way1 filled (clean)
//   Master 2  READ  miss  tag=2  addr=0x0000_0801  → cold miss → way2 filled (clean)
//   Master 3  WRITE miss  tag=3  addr=0x0000_0C01  → cold miss → way3 filled (dirty)
//   Master 4  READ  miss  tag=4  addr=0x0000_1001  → set has ways 0-2 valid, way3 free
//                                                    (way3 is cold) → cold miss way3
//             BUT if all 4 ways are occupied (after M0-M3 fill ways 0-3), tag=4 forces
//             eviction of dirty way0 → writeback + refill
// Wait ordering:
//   Masters 0,1,2 fire in parallel (fork/join_none), then wait fork.
//   Master 3 fires AFTER 0,1,2 complete — ensuring way0 is clean in cache
//   before the write miss makes it dirty.
//   Master 4 fires AFTER master 3 completes — ensuring dirty line exists
//   before the evicting read.
//--------------------------------------------------------------------------------------------
class axi4_virtual_read_miss_seq_with_writeback extends axi4_virtual_base_seq;
  `uvm_object_utils(axi4_virtual_read_miss_seq_with_writeback)

  axi4_master_read_miss_seq   m_rd_miss_seq [NO_OF_MASTERS];
  axi4_master_write_miss_seq  m_wr_miss_seq;

  axi4_slave_writeback_seq    s_wb_seq      [NO_OF_SLAVES];
  axi4_slave_refill_seq       s_refill_seq  [NO_OF_SLAVES];

  function new(string name = "axi4_virtual_read_miss_seq_with_writeback");
    super.new(name);
  endfunction

  task body();
    super.body();

    `uvm_info(get_type_name(), "STARTING READ-MISS + DIRTY EVICTION TEST", UVM_LOW)

    fork

      // ----------------------------------------------------------------
      // THREAD 1 — SLAVE BACKGROUND LOOPS (run forever)
      // ----------------------------------------------------------------
      begin
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
          automatic int slv_idx = s;

          s_wb_seq[s]     = axi4_slave_writeback_seq::type_id::create(
                              $sformatf("s_wb_seq[%0d]",     s));
          s_refill_seq[s] = axi4_slave_refill_seq::type_id::create(
                              $sformatf("s_refill_seq[%0d]", s));

          fork
            forever s_wb_seq[slv_idx].start(
                      p_sequencer.axi4_slave_write_seqr_h[slv_idx]);
            forever s_refill_seq[slv_idx].start(
                      p_sequencer.axi4_slave_read_seqr_h[slv_idx]);
          join_none
        end
      end

      // ----------------------------------------------------------------
      // THREAD 2 — MASTER TRANSACTIONS (ordered in 3 phases)
      // ----------------------------------------------------------------
      begin

        // ── PHASE 1: Masters 0, 1, 2 — parallel cold read misses ─────
        // tag0=way0(clean), tag1=way1(clean), tag2=way2(clean)
        `uvm_info(get_type_name(), "PHASE 1: Masters 0,1,2 cold read misses", UVM_LOW)
        begin
          for (int m = 0; m < 3; m++) begin
            automatic int local_m = m;

            m_rd_miss_seq[m] = axi4_master_read_miss_seq::type_id::create(
                                 $sformatf("m_rd_miss_seq[%0d]", m));
            m_rd_miss_seq[m].txn_addr = (32'(local_m) << 10) | 32'h1;
            m_rd_miss_seq[m].txn_num  = local_m;

            fork
              begin
                m_rd_miss_seq[local_m].start(
                  p_sequencer.axi4_master_read_seqr_h[local_m]);
                `uvm_info(get_type_name(),
                  $sformatf("DONE PHASE1 READ MISS M[%0d] addr=0x%0h",
                             local_m, m_rd_miss_seq[local_m].txn_addr),
                  UVM_LOW)
              end
            join_none
          end
          wait fork;  // wait for all 3 read misses to complete
        end

        // ── PHASE 2: Master 3 — write miss to tag=0 (same addr as M0) ─
        // New address tag=3 not in cache → write miss → allocates way3 +
        // merges write data → way3 becomes DIRTY
        `uvm_info(get_type_name(), "PHASE 2: Master 3 write miss tag=3 addr=0x0C01 -> dirty way3", UVM_LOW)
        begin
          m_wr_miss_seq = axi4_master_write_miss_seq::type_id::create("m_wr_miss_seq");
          m_wr_miss_seq.txn_addr = 32'h0000_0C01;  // tag=3, index=0 -> genuine write miss -> way3 dirty
          m_wr_miss_seq.txn_num  = 3;

          m_wr_miss_seq.start(p_sequencer.axi4_master_write_seqr_h[3]);

          `uvm_info(get_type_name(),
            "DONE PHASE2: way3 is now DIRTY", UVM_LOW)
        end

        // ── PHASE 3: Master 4 — read miss to tag=4 ───────────────────
        // Ways 0,1,2(clean) and way3(dirty) are valid; way3 may be cold.
        // All 4 ways occupied → LRU evicts dirty way3 →
        //   writeback on AW/W then refill on AR/R
        `uvm_info(get_type_name(), "PHASE 3: Master 4 read miss tag=4 -> eviction of dirty way3", UVM_LOW)
        begin
          m_rd_miss_seq[4] = axi4_master_read_miss_seq::type_id::create("m_rd_miss_seq[4]");
          m_rd_miss_seq[4].txn_addr = 32'h0000_1001;  // tag=4, index=0, offset=1
          m_rd_miss_seq[4].txn_num  = 4;

          m_rd_miss_seq[4].start(p_sequencer.axi4_master_read_seqr_h[4]);

          `uvm_info(get_type_name(),
            $sformatf("DONE PHASE3 READ MISS M[4] addr=0x%0h — dirty way3 evicted, new line filled",
                       m_rd_miss_seq[4].txn_addr),
            UVM_LOW)
        end

      end // Thread 2

    join // outer fork

    `uvm_info(get_type_name(), "READ-MISS + DIRTY EVICTION TEST COMPLETE", UVM_LOW)

  endtask

endclass

`endif
