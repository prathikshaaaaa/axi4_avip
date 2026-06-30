

`ifndef AXI4_VIRTUAL_STRESS_SEQ_INCLUDED_
`define AXI4_VIRTUAL_STRESS_SEQ_INCLUDED_

class axi4_virtual_stress_seq extends axi4_virtual_base_seq;
  `uvm_object_utils(axi4_virtual_stress_seq)

  // 1. Declare Arrays of Sequences
  axi4_master_write_miss_seq m_seq[NO_OF_MASTERS];
  
  axi4_slave_writeback_seq   s_wb_seq[NO_OF_SLAVES];
  axi4_slave_refill_seq      s_refill_seq[NO_OF_SLAVES];

  function new(string name = "axi4_virtual_stress_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info(get_type_name(), "STARTING MULTI-MASTER STRESS TEST", UVM_LOW)

    // ---------------------------------------------------------
    // 2. BOOT UP ALL SLAVES (BACKGROUND THREADS)
    // ---------------------------------------------------------
    fork
    begin 
      for (int s = 0; s < NO_OF_SLAVES; s++) begin
        automatic int slv_idx;
      
        s_wb_seq[s]     = axi4_slave_writeback_seq::type_id::create($sformatf("s_wb_seq[%0d]", s));
        s_refill_seq[s] = axi4_slave_refill_seq::type_id::create($sformatf("s_refill_seq[%0d]", s));
      
        slv_idx = s;
      
        fork
          forever s_wb_seq[slv_idx].start(p_sequencer.axi4_slave_write_seqr_h[slv_idx]);
          forever s_refill_seq[slv_idx].start(p_sequencer.axi4_slave_read_seqr_h[slv_idx]);
        join_none
      end
    end 
    // ---------------------------------------------------------
    // 3. FIRE ALL MASTERS AT THE EXACT SAME TIME
    // ---------------------------------------------------------
    begin 
      for (int m = 0; m < NO_OF_MASTERS; m++) begin
  
        automatic int mst_idx;
      
        m_seq[m] = axi4_master_write_miss_seq::type_id::create($sformatf("m_seq[%0d]", m));
        m_seq[m].txn_num = m;
      // Randomize each master to target different random addresses
        if(!m_seq[m].randomize()) begin
           `uvm_fatal("STRESS_SEQ", "Master randomization failed")
        end

        mst_idx = m;
      
        fork
          // This fires the masters in parallel
          m_seq[mst_idx].start(p_sequencer.axi4_master_write_seqr_h[mst_idx]);
        join_none
      end

    // 4. WAIT FOR ALL MASTERS TO FINISH
    // This blocks until all CPU sequences have completed.
    // We do NOT wait for the slaves, because they are running forever!
      wait fork;
    end 
    join
    `uvm_info(get_type_name(), "MULTI-MASTER STRESS TEST COMPLETE", UVM_LOW)
  endtask

endclass

`endif
