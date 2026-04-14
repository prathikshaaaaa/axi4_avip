`ifndef AXI4_WRITE_MISS_TEST_INCLUDED_
`define AXI4_WRITE_MISS_TEST_INCLUDED_

class axi4_write_miss_test extends axi4_base_test;
  `uvm_component_utils(axi4_write_miss_test)

  axi4_virtual_stress_seq vseq;

  function new(string name = "axi4_write_miss_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);

    super.run_phase(phase);

    phase.raise_objection(this);

    `uvm_info(get_type_name(), "TEST STARTED: WRITE MISS", UVM_LOW)

    // Create virtual sequence
    vseq = axi4_virtual_stress_seq::type_id::create("vseq");

    // Start on virtual sequencer
    vseq.start(env.v_sequencer);

    `uvm_info(get_type_name(), "TEST COMPLETED", UVM_LOW)

    phase.drop_objection(this);

  endtask

endclass

`endif 
