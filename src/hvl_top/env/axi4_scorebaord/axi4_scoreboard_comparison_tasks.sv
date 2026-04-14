
task axi4_scoreboard::axi4_write_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  // ------------------------------------------------------------------
  // R1 — AWID
  // ------------------------------------------------------------------
  if(exp_tx.awid === act_tx.awid) begin
    byte_data_cmp_verified_awid_count++;
    `uvm_info("AW_CMP_AWID_OK",
      $sformatf("M[%0d]->S[%0d] AWID match: 0x%0h",
                master_id, slave_id, act_tx.awid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_awid_count++;
    `uvm_error("AW_CMP_AWID_FAIL",
      $sformatf("M[%0d]->S[%0d] AWID mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.awid, act_tx.awid))
  end

  // ------------------------------------------------------------------
  // R2 — AWADDR
  // For cache-line writebacks the slave sees the cache-line-aligned base
  // address, not necessarily the exact byte address the master wrote to.
  // For non-cacheable / device traffic the exact address is forwarded.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    bit [ADDR_WIDTH-1:0] expected_addr;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0 /*is_read=0*/);

    if(policy.cacheable && !policy.device)
      // Writeback: DUT issues cache-line-aligned address
      expected_addr = get_line_base_addr(exp_tx.awaddr);
    else
      // Bypass: exact address forwarded
      expected_addr = exp_tx.awaddr;

    if(act_tx.awaddr === expected_addr) begin
      byte_data_cmp_verified_awaddr_count++;
      `uvm_info("AW_CMP_AWADDR_OK",
        $sformatf("M[%0d]->S[%0d] AWADDR match: 0x%0h",
                  master_id, slave_id, act_tx.awaddr),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awaddr_count++;
      `uvm_error("AW_CMP_AWADDR_FAIL",
        $sformatf("M[%0d]->S[%0d] AWADDR mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_addr, act_tx.awaddr))
    end
  end

  // ------------------------------------------------------------------
  // R3 — AWLEN
  // Cache writeback bursts must be exactly WORDS_PER_LINE beats long.
  // For non-cacheable bypass, master AWLEN is forwarded verbatim.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    int expected_len;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device)
      expected_len = WORDS_PER_LINE - 1;   // full cache-line writeback
    else
      expected_len = exp_tx.awlen;          // bypass: exact forwarding

    if(act_tx.awlen === expected_len) begin
      byte_data_cmp_verified_awlen_count++;
      `uvm_info("AW_CMP_AWLEN_OK",
        $sformatf("M[%0d]->S[%0d] AWLEN match: %0d",
                  master_id, slave_id, act_tx.awlen),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awlen_count++;
      `uvm_error("AW_CMP_AWLEN_FAIL",
        $sformatf("M[%0d]->S[%0d] AWLEN mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_len, act_tx.awlen))
    end
  end

  // ------------------------------------------------------------------
  // R4 — AWSIZE
  // Writeback beats must use the full bus width.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    int expected_size;
    int full_bus_size;

    full_bus_size = $clog2(DATA_WIDTH / 8);  // e.g. 3 for 64-bit bus
    policy        = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device)
      expected_size = full_bus_size;
    else
      expected_size = exp_tx.awsize;

    if(act_tx.awsize === expected_size) begin
      byte_data_cmp_verified_awsize_count++;
      `uvm_info("AW_CMP_AWSIZE_OK",
        $sformatf("M[%0d]->S[%0d] AWSIZE match: %0d",
                  master_id, slave_id, act_tx.awsize),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awsize_count++;
      `uvm_error("AW_CMP_AWSIZE_FAIL",
        $sformatf("M[%0d]->S[%0d] AWSIZE mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_size, act_tx.awsize))
    end
  end

  // ------------------------------------------------------------------
  // R5 — AWBURST
  // Cache writeback must always use INCR (2'b01).
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    logic [1:0] expected_burst;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device)
      expected_burst = 2'b01;   // INCR — mandatory for cache-line ops
    else
      expected_burst = exp_tx.awburst;

    if(act_tx.awburst === expected_burst) begin
      byte_data_cmp_verified_awburst_count++;
      `uvm_info("AW_CMP_AWBURST_OK",
        $sformatf("M[%0d]->S[%0d] AWBURST match: 0x%0h",
                  master_id, slave_id, act_tx.awburst),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awburst_count++;
      `uvm_error("AW_CMP_AWBURST_FAIL",
        $sformatf("M[%0d]->S[%0d] AWBURST mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_burst, act_tx.awburst))
    end
  end

  // ------------------------------------------------------------------
  // R6 — AWCACHE
  // Cache attributes must be preserved from master to slave.
  // ------------------------------------------------------------------
  if(exp_tx.awcache === act_tx.awcache) begin
    byte_data_cmp_verified_awcache_count++;
    `uvm_info("AW_CMP_AWCACHE_OK",
      $sformatf("M[%0d]->S[%0d] AWCACHE match: 0x%0h",
                master_id, slave_id, act_tx.awcache),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_awcache_count++;
    `uvm_error("AW_CMP_AWCACHE_FAIL",
      $sformatf("M[%0d]->S[%0d] AWCACHE mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.awcache, act_tx.awcache))
  end

  // ------------------------------------------------------------------
  // R7 — AWPROT
  // ------------------------------------------------------------------
  if(exp_tx.awprot === act_tx.awprot) begin
    byte_data_cmp_verified_awprot_count++;
    `uvm_info("AW_CMP_AWPROT_OK",
      $sformatf("M[%0d]->S[%0d] AWPROT match: 0x%0h",
                master_id, slave_id, act_tx.awprot),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_awprot_count++;
    `uvm_error("AW_CMP_AWPROT_FAIL",
      $sformatf("M[%0d]->S[%0d] AWPROT mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.awprot, act_tx.awprot))
  end

  // ------------------------------------------------------------------
  // R8 — AWLOCK
  // AXI4 lock type must be preserved.  Note: LOCK must be NORMAL (1'b0)
  // for cache-line burst operations — exclusive accesses to cacheable
  // lines are illegal per AXI4 spec §A7.
  // ------------------------------------------------------------------
  begin
    axi_cache_policy_s policy;
    logic expected_lock;

    policy = axi_decode_cache_policy(exp_tx.awcache, 0);

    if(policy.cacheable && !policy.device) begin
      expected_lock = 1'b0;  // Must be NORMAL for cache-line ops
      if(exp_tx.awlock !== 1'b0) begin
        `uvm_warning("AW_LOCK_CACHEABLE",
          $sformatf("M[%0d]->S[%0d] Master issued EXCLUSIVE LOCK on cacheable write "
                    "AWADDR=0x%0h — AXI4 spec violation §A7",
                    master_id, slave_id, exp_tx.awaddr))
      end
    end
    else begin
      expected_lock = exp_tx.awlock;
    end

    if(act_tx.awlock === expected_lock) begin
      byte_data_cmp_verified_awlock_count++;
      `uvm_info("AW_CMP_AWLOCK_OK",
        $sformatf("M[%0d]->S[%0d] AWLOCK match: %0b",
                  master_id, slave_id, act_tx.awlock),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_awlock_count++;
      `uvm_error("AW_CMP_AWLOCK_FAIL",
        $sformatf("M[%0d]->S[%0d] AWLOCK mismatch — Expected=%0b Got=%0b",
                  master_id, slave_id, expected_lock, act_tx.awlock))
    end
  end

endtask : axi4_write_address_comparison

task axi4_scoreboard::axi4_write_data_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  axi_cache_policy_s policy;
  policy = axi_decode_cache_policy(exp_tx.awcache, 0 /*is_read=0*/);

  // ------------------------------------------------------------------
  // NON-CACHEABLE / DEVICE BYPASS — exact forwarding
  // ------------------------------------------------------------------
  if(policy.device || !policy.cacheable) begin

    foreach(exp_tx.wdata[beat]) begin

      // R9 — WDATA (per strobe)
      for(int lane = 0; lane < (DATA_WIDTH/8); lane++) begin
        if(exp_tx.wstrb[beat][lane]) begin
          byte exp_byte = exp_tx.wdata[beat][8*lane +: 8];
          byte act_byte = act_tx.wdata[beat][8*lane +: 8];

          if(exp_byte === act_byte) begin
            byte_data_cmp_verified_wdata_count++;
          end
          else begin
            byte_data_cmp_failed_wdata_count++;
            `uvm_error("W_CMP_WDATA_FAIL",
              $sformatf("M[%0d]->S[%0d] WDATA bypass mismatch — "
                        "Beat=%0d Lane=%0d Expected=0x%0h Got=0x%0h",
                        master_id, slave_id,
                        beat, lane, exp_byte, act_byte))
          end
        end
      end

      // R10 — WSTRB
      if(exp_tx.wstrb[beat] === act_tx.wstrb[beat]) begin
        byte_data_cmp_verified_wstrb_count++;
      end
      else begin
        byte_data_cmp_failed_wstrb_count++;
        `uvm_error("W_CMP_WSTRB_FAIL",
          $sformatf("M[%0d]->S[%0d] WSTRB bypass mismatch — "
                    "Beat=%0d Expected=0x%0h Got=0x%0h",
                    master_id, slave_id,
                    beat, exp_tx.wstrb[beat], act_tx.wstrb[beat]))
      end

    end // foreach beat

    // R11 — WLAST on final beat of master burst
    if(act_tx.wlast === 1'b1) begin
      byte_data_cmp_verified_wlast_count++;
    end
    else begin
      byte_data_cmp_failed_wlast_count++;
      `uvm_error("W_CMP_WLAST_FAIL",
        $sformatf("M[%0d]->S[%0d] WLAST not asserted at end of bypass burst",
                  master_id, slave_id))
    end

  end
  else begin

    begin
      logic [(DATA_WIDTH/8)-1:0] expected_strb = {(DATA_WIDTH/8){1'b1}};

      if(act_tx.wstrb[0] === expected_strb) begin
        byte_data_cmp_verified_wstrb_count++;
        `uvm_info("W_CMP_WSTRB_WB_OK",
          $sformatf("M[%0d]->S[%0d] WB WSTRB correct: all-ones",
                    master_id, slave_id),
          UVM_HIGH)
      end
      else begin
        byte_data_cmp_failed_wstrb_count++;
        `uvm_error("W_CMP_WSTRB_WB_FAIL",
          $sformatf("M[%0d]->S[%0d] WB WSTRB non-all-ones: Got=0x%0h — "
                    "AXI4 writeback must write all byte lanes",
                    master_id, slave_id, act_tx.wstrb[0]))
      end
    end
    
    if(act_tx.wstrb[0] === {(DATA_WIDTH/8){1'b1}}) begin
      byte_data_cmp_verified_wdata_count++;
    end

    // R11 — WLAST on final writeback beat
    // WLAST position is validated in run_phase; mirror it here for
    // the verified counter.
    if(act_tx.wlast) begin
      byte_data_cmp_verified_wlast_count++;
      `uvm_info("W_CMP_WLAST_WB_OK",
        $sformatf("M[%0d]->S[%0d] WB WLAST correctly asserted on final beat",
                  master_id, slave_id),
        UVM_HIGH)
    end

  end

endtask : axi4_write_data_comparison


task axi4_scoreboard::axi4_write_response_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  // ------------------------------------------------------------------
  // R12 — BID must echo AWID
  // ------------------------------------------------------------------
  if(act_tx.bid === exp_tx.awid) begin
    byte_data_cmp_verified_bid_count++;
    `uvm_info("B_CMP_BID_OK",
      $sformatf("M[%0d]->S[%0d] BID match: 0x%0h",
                master_id, slave_id, act_tx.bid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_bid_count++;
    `uvm_error("B_CMP_BID_FAIL",
      $sformatf("M[%0d]->S[%0d] BID mismatch — AWID=0x%0h Got BID=0x%0h",
                master_id, slave_id, exp_tx.awid, act_tx.bid))
  end

  // ------------------------------------------------------------------
  // R13 — BRESP encoding check
  // ------------------------------------------------------------------
  case(act_tx.bresp)
    2'b00: begin // OKAY
      byte_data_cmp_verified_bresp_count++;
      `uvm_info("B_CMP_BRESP_OKAY",
        $sformatf("M[%0d]->S[%0d] BRESP=OKAY for AWID=0x%0h",
                  master_id, slave_id, exp_tx.awid),
        UVM_HIGH)
    end

    2'b01: begin // EXOKAY — only legal if AWLOCK was set
      if(exp_tx.awlock === 1'b1) begin
        byte_data_cmp_verified_bresp_count++;
        `uvm_info("B_CMP_BRESP_EXOKAY",
          $sformatf("M[%0d]->S[%0d] BRESP=EXOKAY for exclusive AWID=0x%0h — OK",
                    master_id, slave_id, exp_tx.awid),
          UVM_HIGH)
      end
      else begin
        byte_data_cmp_failed_bresp_count++;
        `uvm_error("B_CMP_BRESP_EXOKAY_ILLEGAL",
          $sformatf("M[%0d]->S[%0d] BRESP=EXOKAY but AWLOCK was NORMAL — "
                    "AXI4 violation AWID=0x%0h",
                    master_id, slave_id, exp_tx.awid))
      end
    end

    2'b10: begin // SLVERR
      byte_data_cmp_failed_bresp_count++;
      `uvm_error("B_CMP_BRESP_SLVERR",
        $sformatf("M[%0d]->S[%0d] BRESP=SLVERR for AWID=0x%0h AWADDR=0x%0h",
                  master_id, slave_id, exp_tx.awid, exp_tx.awaddr))
    end

    2'b11: begin // DECERR
      byte_data_cmp_failed_bresp_count++;
      `uvm_error("B_CMP_BRESP_DECERR",
        $sformatf("M[%0d]->S[%0d] BRESP=DECERR for AWID=0x%0h AWADDR=0x%0h — "
                  "address decode failure",
                  master_id, slave_id, exp_tx.awid, exp_tx.awaddr))
    end

    default: begin
      byte_data_cmp_failed_bresp_count++;
      `uvm_error("B_CMP_BRESP_UNKNOWN",
        $sformatf("M[%0d]->S[%0d] Unknown BRESP=0x%0h AWID=0x%0h",
                  master_id, slave_id, act_tx.bresp, exp_tx.awid))
    end
  endcase

endtask : axi4_write_response_comparison

task axi4_scoreboard::axi4_read_address_comparison(
  input axi4_master_tx exp_tx,
  input axi4_slave_tx  act_tx,
  input int            master_id,
  input int            slave_id
);

  axi_cache_policy_s policy;
  policy = axi_decode_cache_policy(exp_tx.arcache, 1 /*is_read=1*/);

  // ------------------------------------------------------------------
  // R14 — ARID
  // ------------------------------------------------------------------
  if(exp_tx.arid === act_tx.arid) begin
    byte_data_cmp_verified_arid_count++;
    `uvm_info("AR_CMP_ARID_OK",
      $sformatf("M[%0d]->S[%0d] ARID match: 0x%0h",
                master_id, slave_id, act_tx.arid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arid_count++;
    `uvm_error("AR_CMP_ARID_FAIL",
      $sformatf("M[%0d]->S[%0d] ARID mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arid, act_tx.arid))
  end

  // ------------------------------------------------------------------
  // R15 — ARADDR
  // ------------------------------------------------------------------
  begin
    bit [ADDR_WIDTH-1:0] expected_addr;

    if(policy.cacheable && !policy.device)
      expected_addr = get_line_base_addr(exp_tx.araddr);  // refill
    else
      expected_addr = exp_tx.araddr;                       // bypass

    if(act_tx.araddr === expected_addr) begin
      byte_data_cmp_verified_araddr_count++;
      `uvm_info("AR_CMP_ARADDR_OK",
        $sformatf("M[%0d]->S[%0d] ARADDR match: 0x%0h",
                  master_id, slave_id, act_tx.araddr),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_araddr_count++;
      `uvm_error("AR_CMP_ARADDR_FAIL",
        $sformatf("M[%0d]->S[%0d] ARADDR mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_addr, act_tx.araddr))
    end
  end

  // ------------------------------------------------------------------
  // R16 — ARLEN
  // ------------------------------------------------------------------
  begin
    int expected_len;

    if(policy.cacheable && !policy.device)
      expected_len = WORDS_PER_LINE - 1;
    else
      expected_len = exp_tx.arlen;

    if(act_tx.arlen === expected_len) begin
      byte_data_cmp_verified_arlen_count++;
      `uvm_info("AR_CMP_ARLEN_OK",
        $sformatf("M[%0d]->S[%0d] ARLEN match: %0d",
                  master_id, slave_id, act_tx.arlen),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arlen_count++;
      `uvm_error("AR_CMP_ARLEN_FAIL",
        $sformatf("M[%0d]->S[%0d] ARLEN mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_len, act_tx.arlen))
    end
  end

  // ------------------------------------------------------------------
  // R17 — ARSIZE
  // ------------------------------------------------------------------
  begin
    int expected_size;
    int full_bus_size;

    full_bus_size = $clog2(DATA_WIDTH / 8);
    expected_size = (policy.cacheable && !policy.device) ? full_bus_size
                                                         : exp_tx.arsize;

    if(act_tx.arsize === expected_size) begin
      byte_data_cmp_verified_arsize_count++;
      `uvm_info("AR_CMP_ARSIZE_OK",
        $sformatf("M[%0d]->S[%0d] ARSIZE match: %0d",
                  master_id, slave_id, act_tx.arsize),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arsize_count++;
      `uvm_error("AR_CMP_ARSIZE_FAIL",
        $sformatf("M[%0d]->S[%0d] ARSIZE mismatch — Expected=%0d Got=%0d",
                  master_id, slave_id, expected_size, act_tx.arsize))
    end
  end

  // ------------------------------------------------------------------
  // R18 — ARBURST — INCR mandatory for cache-line refills
  // ------------------------------------------------------------------
  begin
    logic [1:0] expected_burst;

    expected_burst = (policy.cacheable && !policy.device) ? 2'b01
                                                          : exp_tx.arburst;

    if(act_tx.arburst === expected_burst) begin
      byte_data_cmp_verified_arburst_count++;
      `uvm_info("AR_CMP_ARBURST_OK",
        $sformatf("M[%0d]->S[%0d] ARBURST match: 0x%0h",
                  master_id, slave_id, act_tx.arburst),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arburst_count++;
      `uvm_error("AR_CMP_ARBURST_FAIL",
        $sformatf("M[%0d]->S[%0d] ARBURST mismatch — Expected=0x%0h Got=0x%0h",
                  master_id, slave_id, expected_burst, act_tx.arburst))
    end
  end

  // ------------------------------------------------------------------
  // R19 — ARCACHE
  // ------------------------------------------------------------------
  if(exp_tx.arcache === act_tx.arcache) begin
    byte_data_cmp_verified_arcache_count++;
    `uvm_info("AR_CMP_ARCACHE_OK",
      $sformatf("M[%0d]->S[%0d] ARCACHE match: 0x%0h",
                master_id, slave_id, act_tx.arcache),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arcache_count++;
    `uvm_error("AR_CMP_ARCACHE_FAIL",
      $sformatf("M[%0d]->S[%0d] ARCACHE mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arcache, act_tx.arcache))
  end

  // ------------------------------------------------------------------
  // R20 — ARPROT
  // ------------------------------------------------------------------
  if(exp_tx.arprot === act_tx.arprot) begin
    byte_data_cmp_verified_arprot_count++;
    `uvm_info("AR_CMP_ARPROT_OK",
      $sformatf("M[%0d]->S[%0d] ARPROT match: 0x%0h",
                master_id, slave_id, act_tx.arprot),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arprot_count++;
    `uvm_error("AR_CMP_ARPROT_FAIL",
      $sformatf("M[%0d]->S[%0d] ARPROT mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arprot, act_tx.arprot))
  end

  // ------------------------------------------------------------------
  // R21 — ARLOCK — must be NORMAL for cacheable refills
  // ------------------------------------------------------------------
  begin
    logic expected_lock;

    if(policy.cacheable && !policy.device) begin
      expected_lock = 1'b0;
      if(exp_tx.arlock !== 1'b0) begin
        `uvm_warning("AR_LOCK_CACHEABLE",
          $sformatf("M[%0d]->S[%0d] Master issued EXCLUSIVE LOCK on cacheable read "
                    "ARADDR=0x%0h — AXI4 spec violation §A7",
                    master_id, slave_id, exp_tx.araddr))
      end
    end
    else begin
      expected_lock = exp_tx.arlock;
    end

    if(act_tx.arlock === expected_lock) begin
      byte_data_cmp_verified_arlock_count++;
      `uvm_info("AR_CMP_ARLOCK_OK",
        $sformatf("M[%0d]->S[%0d] ARLOCK match: %0b",
                  master_id, slave_id, act_tx.arlock),
        UVM_HIGH)
    end
    else begin
      byte_data_cmp_failed_arlock_count++;
      `uvm_error("AR_CMP_ARLOCK_FAIL",
        $sformatf("M[%0d]->S[%0d] ARLOCK mismatch — Expected=%0b Got=%0b",
                  master_id, slave_id, expected_lock, act_tx.arlock))
    end
  end

  // ------------------------------------------------------------------
  // R22 — ARQOS
  // ------------------------------------------------------------------
  if(exp_tx.arqos === act_tx.arqos) begin
    byte_data_cmp_verified_arqos_count++;
    `uvm_info("AR_CMP_ARQOS_OK",
      $sformatf("M[%0d]->S[%0d] ARQOS match: 0x%0h",
                master_id, slave_id, act_tx.arqos),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arqos_count++;
    `uvm_error("AR_CMP_ARQOS_FAIL",
      $sformatf("M[%0d]->S[%0d] ARQOS mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arqos, act_tx.arqos))
  end

  // ------------------------------------------------------------------
  // R23 — ARREGION
  // ------------------------------------------------------------------
  if(exp_tx.arregion === act_tx.arregion) begin
    byte_data_cmp_verified_arregion_count++;
    `uvm_info("AR_CMP_ARREGION_OK",
      $sformatf("M[%0d]->S[%0d] ARREGION match: 0x%0h",
                master_id, slave_id, act_tx.arregion),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_arregion_count++;
    `uvm_error("AR_CMP_ARREGION_FAIL",
      $sformatf("M[%0d]->S[%0d] ARREGION mismatch — Expected=0x%0h Got=0x%0h",
                master_id, slave_id, exp_tx.arregion, act_tx.arregion))
  end

endtask : axi4_read_address_comparison

task automatic axi4_scoreboard::axi4_read_data_comparison(
  input axi4_master_tx exp_tx,
  input axi4_master_tx act_tx,
  input int            master_id,
  input int            slave_id,
  input bit            expected_hit
);

  // ------------------------------------------------------------------
  // R24 — RID
  // ------------------------------------------------------------------
  if(act_tx.arid === exp_tx.arid) begin
    byte_data_cmp_verified_rid_count++;
    `uvm_info("R_CMP_RID_OK",
      $sformatf("M[%0d] S[%0d] RID match: 0x%0h",
                master_id, slave_id, act_tx.arid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_rid_count++;
    `uvm_error("R_CMP_RID_FAIL",
      $sformatf("M[%0d] S[%0d] RID mismatch — ARID=0x%0h Got RID=0x%0h",
                master_id, slave_id, exp_tx.arid, act_tx.arid))
  end

  // ------------------------------------------------------------------
  // R26 — RRESP per beat
  // ------------------------------------------------------------------
  foreach(act_tx.rresp[beat]) begin
    case(act_tx.rresp[beat])
      2'b00: begin // OKAY
        byte_data_cmp_verified_rresp_count++;
      end
      2'b01: begin // EXOKAY
        if(exp_tx.arlock === 1'b1) begin
          byte_data_cmp_verified_rresp_count++;
          `uvm_info("R_CMP_RRESP_EXOKAY",
            $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=EXOKAY for exclusive "
                      "ARID=0x%0h — OK",
                      master_id, slave_id, beat, exp_tx.arid),
            UVM_HIGH)
        end
        else begin
          byte_data_cmp_failed_rresp_count++;
          `uvm_error("R_CMP_RRESP_EXOKAY_ILLEGAL",
            $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=EXOKAY but ARLOCK=NORMAL — "
                      "AXI4 violation ARID=0x%0h",
                      master_id, slave_id, beat, exp_tx.arid))
        end
      end
      2'b10: begin // SLVERR
        byte_data_cmp_failed_rresp_count++;
        `uvm_error("R_CMP_RRESP_SLVERR",
          $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=SLVERR ARID=0x%0h",
                    master_id, slave_id, beat, exp_tx.arid))
      end
      2'b11: begin // DECERR
        byte_data_cmp_failed_rresp_count++;
        `uvm_error("R_CMP_RRESP_DECERR",
          $sformatf("M[%0d] S[%0d] Beat=%0d RRESP=DECERR ARID=0x%0h ARADDR=0x%0h",
                    master_id, slave_id, beat, exp_tx.arid, exp_tx.araddr))
      end
      default: begin
        byte_data_cmp_failed_rresp_count++;
        `uvm_error("R_CMP_RRESP_UNKNOWN",
          $sformatf("M[%0d] S[%0d] Beat=%0d Unknown RRESP=0x%0h",
                    master_id, slave_id, beat, act_tx.rresp[beat]))
      end
    endcase
  end

  // ------------------------------------------------------------------
  // R27 — RLAST
  // act_tx.rlast must be 1 only on the final beat (arlen'th beat).
  // The run_phase pops the pending transaction only after rlast so by
  // the time this task sees it, rlast is expected to be asserted.
  // ------------------------------------------------------------------
  if(act_tx.rlast === 1'b1) begin
    byte_data_cmp_verified_rlast_count++;
    `uvm_info("R_CMP_RLAST_OK",
      $sformatf("M[%0d] S[%0d] RLAST correctly asserted ARID=0x%0h",
                master_id, slave_id, exp_tx.arid),
      UVM_HIGH)
  end
  else begin
    byte_data_cmp_failed_rlast_count++;
    `uvm_error("R_CMP_RLAST_FAIL",
      $sformatf("M[%0d] S[%0d] RLAST NOT asserted at final beat ARID=0x%0h "
                "ARLEN=%0d",
                master_id, slave_id, exp_tx.arid, exp_tx.arlen))
  end

  // ------------------------------------------------------------------
  // R25 — RDATA per beat
  // ------------------------------------------------------------------
  if(expected_hit) begin
    // ================================================================
    // HIT PATH — compare against L3 cache shadow
    // ================================================================
    bit [L3_TAG_BITS-1:0]   tag;
    bit [L3_INDEX_BITS-1:0] index;
    bit [L3_OFFSET_BITS-1:0] offset;
    int hit_way = -1;

    l3_cache_decode_address(exp_tx.araddr, tag, index, offset);

    for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
      if(l3_cache[index][w].valid                &&
         l3_cache[index][w].tag   == tag         &&
         l3_cache[index][w].state != L3_INVALID  &&
         l3_cache[index][w].state != L3_FILLING) begin
        hit_way = w;
        break;
      end
    end

    if(hit_way == -1) begin
      byte_data_cmp_failed_rdata_count++;
      `uvm_error("R_CMP_HIT_WAY_MISSING",
        $sformatf("M[%0d] S[%0d] Expected HIT but cache line not found "
                  "ARADDR=0x%0h",
                  master_id, slave_id, exp_tx.araddr))
    end
    else begin
      int bytes_per_beat = 1 << exp_tx.arsize;
      longint temp_addr  = exp_tx.araddr;
      longint wrap_boundary;
      longint wrap_start_addr;
      longint wrap_end_addr;
      int align_amount;

      wrap_boundary   = bytes_per_beat * (exp_tx.arlen + 1);
      wrap_start_addr = (longint'(exp_tx.araddr) / wrap_boundary) * wrap_boundary;
      wrap_end_addr   = wrap_start_addr + wrap_boundary;
      align_amount    = longint'(exp_tx.araddr) % bytes_per_beat;

      foreach(act_tx.rdata[beat]) begin
        int local_align = (beat == 0) ? align_amount : 0;
        bit beat_ok = 1;

        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int line_offset;
          int lane;
          byte cache_byte;
          byte dut_byte;

          line_offset  = int'(temp_addr) % L3_CACHE_LINE_SIZE_BYTES;
          lane         = int'(temp_addr) % (DATA_WIDTH / 8);
          cache_byte   = l3_cache[index][hit_way].data[line_offset];
          dut_byte     = act_tx.rdata[beat][8*lane +: 8];

          if(cache_byte !== dut_byte) begin
            beat_ok = 0;
            byte_data_cmp_failed_rdata_count++;
            `uvm_error("R_CMP_HIT_DATA_MISMATCH",
              $sformatf("M[%0d] S[%0d] HIT Beat=%0d ByteIdx=%0d "
                        "Addr=0x%0h Lane=%0d "
                        "Expected(cache)=0x%0h Got=0x%0h",
                        master_id, slave_id,
                        beat, byte_idx,
                        temp_addr, lane,
                        cache_byte, dut_byte))
          end

          // Advance address per burst type
          case(exp_tx.arburst)
            2'b00: ; // FIXED — temp_addr stays at araddr
            2'b01: temp_addr++;  // INCR
            2'b10: begin         // WRAP
              temp_addr++;
              if(temp_addr >= wrap_end_addr)
                temp_addr = wrap_start_addr;
            end
            default: temp_addr++;
          endcase
        end

        if(beat_ok) begin
          byte_data_cmp_verified_rdata_count++;
          `uvm_info("R_CMP_HIT_DATA_OK",
            $sformatf("M[%0d] S[%0d] HIT Beat=%0d RDATA OK",
                      master_id, slave_id, beat),
            UVM_HIGH)
        end

      end // foreach beat
    end

  end // HIT PATH
  else begin
    // ================================================================
    // MISS PATH — compare against referenceData[]
    // ================================================================
    int bytes_per_beat = 1 << exp_tx.arsize;
    longint temp_addr  = exp_tx.araddr;
    longint wrap_boundary;
    longint wrap_start_addr;
    longint wrap_end_addr;
    int align_amount;

    wrap_boundary   = bytes_per_beat * (exp_tx.arlen + 1);
    wrap_start_addr = (longint'(exp_tx.araddr) / wrap_boundary) * wrap_boundary;
    wrap_end_addr   = wrap_start_addr + wrap_boundary;
    align_amount    = longint'(exp_tx.araddr) % bytes_per_beat;

    foreach(act_tx.rdata[beat]) begin
      int local_align = (beat == 0) ? align_amount : 0;
      bit beat_ok = 1;

      for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
        int lane = int'(temp_addr) % (DATA_WIDTH / 8);
        byte expected_byte;
        byte dut_byte;

        expected_byte = referenceData[slave_id].exists(temp_addr)
                        ? referenceData[slave_id][temp_addr]
                        : 8'h00;
        dut_byte      = act_tx.rdata[beat][8*lane +: 8];

        if(expected_byte !== dut_byte) begin
          beat_ok = 0;
          byte_data_cmp_failed_rdata_count++;
          `uvm_error("R_CMP_MISS_DATA_MISMATCH",
            $sformatf("M[%0d] S[%0d] MISS Beat=%0d ByteIdx=%0d "
                      "Addr=0x%0h Lane=%0d "
                      "Expected(refMem)=0x%0h Got=0x%0h",
                      master_id, slave_id,
                      beat, byte_idx,
                      temp_addr, lane,
                      expected_byte, dut_byte))
        end

        // Advance address per burst type
        case(exp_tx.arburst)
          2'b00: ; // FIXED
          2'b01: temp_addr++;  // INCR
          2'b10: begin         // WRAP
            temp_addr++;
            if(temp_addr >= wrap_end_addr)
              temp_addr = wrap_start_addr;
          end
          default: temp_addr++;
        endcase
      end

      if(beat_ok) begin
        byte_data_cmp_verified_rdata_count++;
        `uvm_info("R_CMP_MISS_DATA_OK",
          $sformatf("M[%0d] S[%0d] MISS Beat=%0d RDATA OK",
                    master_id, slave_id, beat),
          UVM_HIGH)
      end

    end // foreach beat
  end // MISS PATH

endtask : axi4_read_data_comparison
