`ifndef AXI4_READ_MISS_TEST_INCLUDED_
`define AXI4_READ_MISS_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_read_miss_test
//
// Purpose:
//   Top-level test that exercises cache READ-MISS behaviour:
//     • Master agents issue INCR-4 READ transactions to addresses guaranteed
//       to miss in the cache (unique tag per master, same set index).
//     • The cache controller detects each miss, evicts a dirty line if the
//       set is full (handled by axi4_slave_writeback_seq on the W channel),
//       then fetches the new line from DDR (handled by axi4_slave_refill_seq
//       on the R channel) and returns the data to the requesting master.
//
// Structure (identical to axi4_writeback_test):
//   run_phase
//     └─ axi4_virtual_read_miss_seq.start(axi4_env_h.axi4_virtual_seqr_h)
//--------------------------------------------------------------------------------------------
class axi4_read_miss_test extends axi4_base_test;
  `uvm_component_utils(axi4_read_miss_test)

  axi4_virtual_read_miss_seq vseq;

  function new(string name = "axi4_read_miss_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    `uvm_info(get_type_name(), "TEST STARTED: READ MISS", UVM_LOW)

    vseq = axi4_virtual_read_miss_seq::type_id::create("vseq");
    vseq.start(axi4_env_h.axi4_virtual_seqr_h);

    `uvm_info(get_type_name(), "TEST COMPLETED: READ MISS", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass

`endif
