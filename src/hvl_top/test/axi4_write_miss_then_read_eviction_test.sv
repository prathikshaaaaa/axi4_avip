`ifndef AXI4_WRITE_MISS_THEN_READ_EVICTION_TEST_INCLUDED_
`define AXI4_WRITE_MISS_THEN_READ_EVICTION_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_write_miss_then_read_eviction_test
//
// Purpose:
//   Masters 0-3 each issue one WRITE miss (sequential, each waits for B response)
//   to the same cache set, filling ways 0-3 with dirty data.
//   Master 4 then issues a READ miss to the same set with a new tag — all ways
//   occupied → LRU dirty way evicted → writeback → refill → data returned.
//
// Extends: axi4_base_test
//--------------------------------------------------------------------------------------------
class axi4_write_miss_then_read_eviction_test extends axi4_base_test;
  `uvm_component_utils(axi4_write_miss_then_read_eviction_test)

  axi4_virtual_write_miss_then_read_eviction_seq vseq;

  function new(string name = "axi4_write_miss_then_read_eviction_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    `uvm_info(get_type_name(),
      "TEST STARTED: 4xWRITE-MISS FILL ALL WAYS -> READ-MISS LRU EVICTION",
      UVM_LOW)

    vseq = axi4_virtual_write_miss_then_read_eviction_seq::type_id::create("vseq");
    vseq.start(axi4_env_h.axi4_virtual_seqr_h);

    `uvm_info(get_type_name(),
      "TEST COMPLETED: LRU DIRTY EVICTION + WRITEBACK + REFILL VERIFIED",
      UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass

`endif
