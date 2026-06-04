`ifndef AXI4_READ_MISS_TEST_INCLUDED_
`define AXI4_READ_MISS_TEST_INCLUDED_

class axi4_read_miss_test extends axi4_base_test;

  `uvm_component_utils(axi4_read_miss_test)

  axi4_virtual_read_miss_stress_seq vseq;

  function new(string name="axi4_read_miss_test",
               uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);

    super.run_phase(phase);

    phase.raise_objection(this);

    `uvm_info(get_type_name(),
              "TEST STARTED : READ MISS",
              UVM_LOW)

    vseq =
      axi4_virtual_read_miss_stress_seq::type_id::create(
        "vseq");

    vseq.start(
      axi4_env_h.axi4_virtual_seqr_h);

    `uvm_info(get_type_name(),
              "TEST COMPLETED",
              UVM_LOW)

    phase.drop_objection(this);

  endtask

endclass

`endif
