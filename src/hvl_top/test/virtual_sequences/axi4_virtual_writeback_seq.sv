`ifndef AXI4_VIRTUAL_WRITEBACK_SEQ_INCLUDED_
`define AXI4_VIRTUAL_WRITEBACK_SEQ_INCLUDED_

class axi4_virtual_writeback_seq extends axi4_virtual_base_seq;
  `uvm_object_utils(axi4_virtual_writeback_seq)

  axi4_master_writeback_seq  m_wb_seq    [NO_OF_MASTERS];
  axi4_slave_writeback_seq   s_wb_seq    [NO_OF_SLAVES];
  axi4_slave_refill_seq      s_refill_seq[NO_OF_SLAVES];

  function new(string name = "axi4_virtual_writeback_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info(get_type_name(), "STARTING WRITEBACK TEST", UVM_LOW)

    fork

      // ------------------------------------------------------------------
      // THREAD 1: SLAVE BACKGROUND THREADS
      // Spawns forever loops as children of Thread 1, then exits immediately.
      // ------------------------------------------------------------------
      begin
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
          automatic int slv_idx = s;
          s_wb_seq[s]     = axi4_slave_writeback_seq::type_id::create($sformatf("s_wb_seq[%0d]", s));
          s_refill_seq[s] = axi4_slave_refill_seq::type_id::create($sformatf("s_refill_seq[%0d]", s));
          fork
            forever s_wb_seq[slv_idx].start(p_sequencer.axi4_slave_write_seqr_h[slv_idx]);
            forever s_refill_seq[slv_idx].start(p_sequencer.axi4_slave_read_seqr_h[slv_idx]);
          join_none
        end
      end

      // ------------------------------------------------------------------
      // THREAD 2: MASTER THREADS — all 5 fire in parallel
      //
      // Address scheme:
      //   addr = (i << 10) | 32'h1
      //   Bits[3:0]   = byte offset  (4-beat line, 4-byte word -> 4 bits)
      //   Bits[9:4]   = set index    (fixed 0 -> all hit same cache set)
      //   Bits[31:10] = tag          (unique per master -> unique way fill)
      //
      //   TXN0 -> tag=0 -> fills way0
      //   TXN1 -> tag=1 -> fills way1
      //   TXN2 -> tag=2 -> fills way2
      //   TXN3 -> tag=3 -> fills way3  (set full, ASSOCIATIVITY=4)
      //   TXN4 -> tag=4 -> triggers eviction + writeback of dirty way
      //
      // M0->TXN0, M1->TXN1, M2->TXN2, M3->TXN3, M4->TXN4
      // One txn per master — no awvalid contention on same sequencer.
      // ------------------------------------------------------------------
      begin
        for (int m = 0; m < NO_OF_MASTERS; m++) begin
          automatic int local_m   = m;
          automatic int local_num = m;
          m_wb_seq[m]          = axi4_master_writeback_seq::type_id::create($sformatf("m_wb_seq_%0d", m));
          m_wb_seq[m].txn_addr = (local_num << 10) | 32'h1;
          m_wb_seq[m].txn_num  = local_num;
          fork
            begin
              m_wb_seq[local_m].start(p_sequencer.axi4_master_write_seqr_h[local_m]);
              `uvm_info(get_type_name(),
                $sformatf("DONE TXN[%0d] M[%0d] addr=0x%0h",
                           local_num, local_m, m_wb_seq[local_m].txn_addr),
                UVM_LOW)
            end
          join_none
        end
        // Scoped to Thread 2's process — sees ONLY the master join_none
        // threads above, NOT Thread 1's slave forever loops
        wait fork;
      end

    join

    `uvm_info(get_type_name(), "WRITEBACK TEST COMPLETE", UVM_LOW)
  endtask

endclass

`endif
