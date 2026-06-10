`ifndef AXI4_READ_MISS_WITH_WRITEBACK_TEST_INCLUDED_
`define AXI4_READ_MISS_WITH_WRITEBACK_TEST_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: axi4_read_miss_with_writeback_test
//
// Purpose:
//   Top-level test that exercises the full read-miss + dirty-eviction path:
//     Phase 1 — Masters 0,1,2 issue parallel READ misses (cold fills, clean)
//                 tag=0 → way0, tag=1 → way1, tag=2 → way2
//     Phase 2 — Master 3 issues a WRITE miss to tag=3 → way3 filled and
//                 marked DIRTY (write-allocate + merge)
//     Phase 3 — Master 4 issues a READ miss to tag=4 → all 4 ways occupied
//                 → LRU evicts dirty way3 → writeback on AW/W channel
//                 → refill on AR/R channel → data returned to master 4
//
// Extends: axi4_base_test (inherits env build, config setup, drain time)
//--------------------------------------------------------------------------------------------
class axi4_read_miss_with_writeback_test extends axi4_base_test;
  `uvm_component_utils(axi4_read_miss_with_writeback_test)

  axi4_virtual_read_miss_seq_with_writeback vseq;

  function new(string name = "axi4_read_miss_with_writeback_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    `uvm_info(get_type_name(),
      "TEST STARTED: READ MISS + DIRTY EVICTION + WRITEBACK", UVM_LOW)

    vseq = axi4_virtual_read_miss_seq_with_writeback::type_id::create("vseq");
    vseq.start(axi4_env_h.axi4_virtual_seqr_h);

    `uvm_info(get_type_name(),
      "TEST COMPLETED: READ MISS + DIRTY EVICTION + WRITEBACK", UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass

`endif
