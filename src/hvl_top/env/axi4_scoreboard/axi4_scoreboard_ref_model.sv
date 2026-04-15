//=============================================================================
// FILE: axi4_scoreboard_ref_model.sv
// CONTAINS: Reference model and arbitration logic
//   - get_slave_index
//   - check_write_rr_arbitration
//   - check_read_rr_arbitration
//   - ref_model_write
//   - ref_model_read
//   - l3_handle_read_request
//   - l3_handle_write_request
//   - l3_handle_write_data
// Included by axi4_scoreboard.sv — NOT a standalone compilation unit
//=============================================================================

//=============================================================================
// Function: get_slave_index
//=============================================================================
function int axi4_scoreboard::get_slave_index(logic[ADDR_WIDTH-1:0] addr);
  for(int i = 0; i < NO_OF_SLAVES; i++) begin
    if(addr >= SLAVE_START_ADDR[i] && addr <= SLAVE_END_ADDR[i]) begin
      return i;
    end
  end
  return -1;
endfunction : get_slave_index

//=============================================================================
// Function: check_write_rr_arbitration
//=============================================================================
function void axi4_scoreboard::check_write_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_write_grants++;
  
  search_count = 0;
  found_pending = 0;
  expected_master = rr_write_next_master[slave_id];
  
  while(search_count < NO_OF_MASTERS) begin
    if(rr_write_pending_cnt[slave_id][expected_master] > 0) begin
      found_pending = 1;
      break;
    end
    expected_master = (expected_master + 1) % NO_OF_MASTERS;
    search_count++;
  end
  
  if(!found_pending) begin
    `uvm_info("RR_WRITE_NO_CONTENTION", 
              $sformatf("Slave[%0d]: No contention, granted to Master[%0d]", slave_id, granted_master), 
              UVM_HIGH)
    rr_write_last_granted[slave_id] = granted_master;
    return;
  end
  
  if(granted_master != expected_master) begin
    `uvm_error("RR_WRITE_VIOLATION",
              $sformatf("Slave[%0d] Write RR Arbitration Violation: Expected M%0d, Granted M%0d",
                       slave_id, expected_master, granted_master))
    rr_write_violations++;
  end
  
  rr_write_next_master[slave_id] = (granted_master + 1) % NO_OF_MASTERS;
  rr_write_last_granted[slave_id] = granted_master;
  
  if(rr_write_pending_cnt[slave_id][granted_master] > 0) begin
    rr_write_pending_cnt[slave_id][granted_master]--;
  end
  
endfunction : check_write_rr_arbitration

//=============================================================================
// Function: check_read_rr_arbitration
//=============================================================================
function void axi4_scoreboard::check_read_rr_arbitration(int slave_id, int granted_master);
  int expected_master;
  int search_count;
  bit found_pending;
  
  rr_read_grants++;
  
  search_count = 0;
  found_pending = 0;
  expected_master = rr_read_next_master[slave_id];
  
  while(search_count < NO_OF_MASTERS) begin
    if(rr_read_pending_cnt[slave_id][expected_master] > 0) begin
      found_pending = 1;
      break;
    end
    expected_master = (expected_master + 1) % NO_OF_MASTERS;
    search_count++;
  end
  
  if(!found_pending) begin
    `uvm_info("RR_READ_NO_CONTENTION", 
              $sformatf("Slave[%0d]: No contention, granted to Master[%0d]", slave_id, granted_master), 
              UVM_HIGH)
    rr_read_last_granted[slave_id] = granted_master;
    return;
  end
  
  if(granted_master != expected_master) begin
    `uvm_error("RR_READ_VIOLATION",
              $sformatf("Slave[%0d] Read RR Arbitration Violation: Expected M%0d, Granted M%0d",
                       slave_id, expected_master, granted_master))
    rr_read_violations++;
  end
  
  rr_read_next_master[slave_id] = (granted_master + 1) % NO_OF_MASTERS;
  rr_read_last_granted[slave_id] = granted_master;
  
  if(rr_read_pending_cnt[slave_id][granted_master] > 0) begin
    rr_read_pending_cnt[slave_id][granted_master]--;
  end
  
endfunction : check_read_rr_arbitration

//=============================================================================
// Function: ref_model_write
// Pass slave_idx to l3_handle_write_request
//=============================================================================
function void axi4_scoreboard::ref_model_write(axi4_master_tx m_tx, int slave_idx, int master_idx);
  int bytes_per_beat;
  longint temp_addr;
  int align_amount;
  longint wrap_start_addr;
  longint wrap_end_addr;
  longint wrap_boundary;
  
  bytes_per_beat = 1 << m_tx.awsize;
  temp_addr = m_tx.awaddr;
  
  wrap_boundary = bytes_per_beat * (m_tx.awlen + 1);
  wrap_start_addr = (temp_addr / wrap_boundary) * wrap_boundary;
  wrap_end_addr = wrap_start_addr + wrap_boundary;
  
  align_amount = temp_addr % bytes_per_beat;
  
  foreach(m_tx.wdata[beat]) begin
    int local_align = (beat == 0) ? align_amount : 0;
    
    case(m_tx.awburst)
      2'b00: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          longint byte_addr = m_tx.awaddr + byte_idx;
          int lane = byte_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][byte_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
          end
        end
      end
      
      2'b01: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
          end
          temp_addr++;
        end
      end
      
      2'b10: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(m_tx.wstrb[beat][lane]) begin
            referenceData[slave_idx][temp_addr] = m_tx.wdata[beat][8*lane+7 -: 8];
          end
          temp_addr++;
          if(temp_addr >= wrap_end_addr) begin
            temp_addr = wrap_start_addr;
          end
        end
      end
    endcase
  end
  
  // L3 cache handles its own memory updates based on policy
  l3_handle_write_request(master_idx, m_tx, slave_idx);
  
endfunction : ref_model_write

//=============================================================================
// Function: ref_model_read
//=============================================================================
function void axi4_scoreboard::ref_model_read(axi4_master_tx m_tx, int slave_idx);
  int bytes_per_beat;
  longint temp_addr;
  int align_amount;
  longint wrap_start_addr;
  longint wrap_end_addr;
  longint wrap_boundary;
  
  bytes_per_beat = 1 << m_tx.arsize;
  temp_addr = m_tx.araddr;
  
  wrap_boundary = bytes_per_beat * (m_tx.arlen + 1);
  wrap_start_addr = (temp_addr / wrap_boundary) * wrap_boundary;
  wrap_end_addr = wrap_start_addr + wrap_boundary;
  
  align_amount = temp_addr % bytes_per_beat;
  
  m_tx.rdata = new[m_tx.arlen + 1];
  
  foreach(m_tx.rdata[beat]) begin
    int local_align = (beat == 0) ? align_amount : 0;
    m_tx.rdata[beat] = '0;
    
    case(m_tx.arburst)
      2'b00: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          longint byte_addr = m_tx.araddr + byte_idx;
          int lane = byte_addr % (DATA_WIDTH/8);
          
          if(referenceData[slave_idx].exists(byte_addr)) begin
            m_tx.rdata[beat][8*lane+7 -: 8] = referenceData[slave_idx][byte_addr];
          end else begin
            m_tx.rdata[beat][8*lane+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
        end
      end
      
      2'b01: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(referenceData[slave_idx].exists(temp_addr)) begin
            m_tx.rdata[beat][8*lane+7 -: 8] = referenceData[slave_idx][temp_addr];
          end else begin
            m_tx.rdata[beat][8*lane+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
          temp_addr++;
        end
      end
      
      2'b10: begin
        for(int byte_idx = local_align; byte_idx < bytes_per_beat; byte_idx++) begin
          int lane = temp_addr % (DATA_WIDTH/8);
          
          if(referenceData[slave_idx].exists(temp_addr)) begin
            m_tx.rdata[beat][8*lane+7 -: 8] = referenceData[slave_idx][temp_addr];
          end else begin
            m_tx.rdata[beat][8*lane+7 -: 8] = 8'h00;
            nonExistantMemRead++;
          end
          temp_addr++;
          if(temp_addr >= wrap_end_addr) begin
            temp_addr = wrap_start_addr;
          end
        end
      end
    endcase
  end
  
endfunction : ref_model_read

//==========================================================================
//  L3 HANDLE READ REQUEST
//==========================================================================
function void axi4_scoreboard::l3_handle_read_request(
    input int master_id,
    input axi4_master_tx m_tx,
    output bit expected_hit
  );
  
  axi_cache_policy_s policy; // policy : decoded AXI AxCACHE behavior
  int hit_way; // hit_way : which way matched (if hit)
  l3_state_e state; // state : CLEAN / DIRTY / INVALID / FILLING
  
  bit [L3_TAG_BITS-1:0] tag;           // Used for,
  bit [L3_INDEX_BITS-1:0] index;       //  - Address breakdown
  bit [L3_OFFSET_BITS-1:0] offset;     //  - LRU updates
  
  int mshr_id; // If miss -> we allocate an MSHR entry.

  expected_hit = 0; // Intially take it as zero...assumed miss!
  
  // ------------------------------------------------------------------------------
  // 1. Decode AXI cache policy
  // ------------------------------------------------------------------------------
  // Purpose: Converts the raw 4-bit AxCACHE signal into readable memory attributes
  // (Device, Cacheable, Write-Back/Through, Allocation).
  policy = axi_decode_cache_policy(m_tx.arcache, 1);
  
  // ------------------------------------------------------------------------------
  // 2. Device / Non-cacheable
  // ------------------------------------------------------------------------------
  // Purpose: Bypasses L3 for Device or Non-cacheable traffic per AXI rules.
  // Prevents state side-effects: No MSHR allocation, LRU updates, or counter increments.
  if(policy.device || !policy.cacheable) begin
    `uvm_info("L3_READ_BYPASS",
      $sformatf("M[%0d] Addr=0x%0h Non-cacheable",
                master_id, m_tx.araddr),
      UVM_MEDIUM)
    return;
  end
  
  // ------------------------------------------------------------------------------
  // 3. Decode address
  // ------------------------------------------------------------------------------
  // Purpose: Splits raw address into Tag, Index, and Offset fields.
  // Necessary for set-associative indexing and byte-level offset tracking.
  l3_cache_decode_address(m_tx.araddr, tag, index, offset);

  // ------------------------------------------------------------------------------
  // 4. Lookup
  // ------------------------------------------------------------------------------
  // Purpose: Validates Tag match against active lines (checks Valid, Filling, and Lock states).
  // Determines if the transaction is a HIT or requires a MISS/Bypass flow.
  if(l3_cache_lookup(m_tx.araddr, policy, hit_way, state)) begin : L3_READ_HIT
    // ================= READ HIT =================
    expected_hit = 1;

    l3_read_hits_per_master[master_id]++;
    l3_total_read_hits++;

    // Update LRU only on hit
    l3_update_lru(index, hit_way);

    `uvm_info("L3_READ_HIT",
      $sformatf("M[%0d] HIT Set=%0d Way=%0d Addr=0x%0h State=%s",
                master_id, index, hit_way,
                m_tx.araddr, state.name()),
      UVM_MEDIUM)
    
  end : L3_READ_HIT
  else begin : L3_READ_MISS
    // ================= READ MISS =================
    expected_hit = 0;

    l3_read_misses_per_master[master_id]++;
    l3_total_read_misses++;

    mshr_id = scb_allocate_mshr(
                m_tx.araddr,   // addr
                master_id,     // master
                m_tx.arid,     // txn_id
                0              // is_write=0 for reads
              );

    if(mshr_id == -1) begin
      `uvm_warning("L3_READ_MISS_STALL",
        $sformatf("MSHR full for Addr=0x%0h",
                  m_tx.araddr))
      return;
    end

    `uvm_info("L3_READ_MISS",
      $sformatf("M[%0d] MISS Set=%0d Addr=0x%0h → MSHR[%0d]",
                master_id, index,
                m_tx.araddr, mshr_id),
      UVM_MEDIUM)
  end : L3_READ_MISS
  
endfunction : l3_handle_read_request

//==========================================================================
//  L3 HANDLE WRITE REQUEST
//==========================================================================
    
function void axi4_scoreboard::l3_handle_write_request(
  input int master_id,
  input axi4_master_tx m_tx,
  input int slave_idx
);

  axi_cache_policy_s policy;
  int hit_way;
  l3_state_e state;

  bit [L3_TAG_BITS-1:0]   tag;
  bit [L3_INDEX_BITS-1:0] index;
  bit [L3_OFFSET_BITS-1:0] offset;

  policy = axi_decode_cache_policy(m_tx.awcache, 0);

  // bypass
  if(policy.device || !policy.cacheable)
    return;

  l3_cache_decode_address(m_tx.awaddr, tag, index, offset);

  //--------------------------------------------
  // WRITE HIT
  //--------------------------------------------
  if(l3_cache_lookup(m_tx.awaddr, policy, hit_way, state)) begin

    scb_write_locked       = 1;
    scb_write_owner        = master_id;
    scb_write_owner_set    = index;
    scb_write_owner_way    = hit_way;
    scb_write_owner_is_hit = 1;

    l3_write_hits_per_master[master_id]++;
    l3_total_write_hits++;

    `uvm_info("L3_WRITE_HIT",
      $sformatf("M[%0d] HIT Set=%0d Way=%0d Addr=0x%0h",
        master_id, index, hit_way, m_tx.awaddr),
      UVM_MEDIUM)

  end
  //--------------------------------------------
  // WRITE MISS
  //--------------------------------------------
  else begin
    int mshr_id;

    mshr_id = scb_allocate_mshr(
      m_tx.awaddr,
      master_id,
      m_tx.awid,
      1
    );

    if(mshr_id == -1) begin
      `uvm_error("L3_WRITE_MISS", "MSHR allocation failed")
      return;
    end

    l3_write_misses_per_master[master_id]++;
    l3_total_write_misses++;

    `uvm_info("L3_WRITE_MISS",
      $sformatf("M[%0d] MISS Addr=0x%0h → MSHR[%0d]",
        master_id, m_tx.awaddr, mshr_id),
      UVM_MEDIUM)
  end

endfunction
  
//==========================================================================
//  L3 HANDLE WRITE DATA
//==========================================================================
    
function void axi4_scoreboard::l3_handle_write_data(
  input int master_id,
  input axi4_master_tx m_tx
);

  //--------------------------------------------
  // 1. WRITE MISS : BUFFER IN MSHR
  //--------------------------------------------
  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid &&
       scb_mshr[i].is_write &&
       scb_mshr[i].master == master_id &&
       scb_mshr[i].txn_id == m_tx.awid &&
       !scb_mshr[i].done) begin

      int b = scb_mshr[i].wbeat_count;

      foreach(m_tx.wdata[beat]) begin
        if(b < WORDS_PER_LINE) begin
          scb_mshr[i].wdata_buf[b] = m_tx.wdata[beat];
          scb_mshr[i].wstrb_buf[b] = m_tx.wstrb[beat];
          b++;
        end
      end

      scb_mshr[i].wbeat_count = b;

      `uvm_info("L3_WDATA_MISS",
        $sformatf("Buffered WDATA in MSHR[%0d]", i),
        UVM_HIGH)

      return;
    end
  end

  //--------------------------------------------
  // 2. WRITE HIT : MERGE INTO CACHE
  //--------------------------------------------
  if(scb_write_locked && scb_write_owner == master_id) begin

    int set = scb_write_owner_set;
    int way = scb_write_owner_way;

    longint temp_addr = m_tx.awaddr;

    foreach(m_tx.wdata[beat]) begin
      for(int b = 0; b < (DATA_WIDTH/8); b++) begin

        int line_offset = temp_addr % L3_CACHE_LINE_SIZE_BYTES;

        if(m_tx.wstrb[beat][b]) begin
          l3_cache[set][way].data[line_offset] =
            m_tx.wdata[beat][8*b +: 8];
        end

        temp_addr++;
      end
    end

    l3_set_line_state(set, way, L3_DIRTY);
    l3_update_lru(set, way);

    `uvm_info("L3_WDATA_HIT",
      $sformatf("Merged WDATA into cache Set=%0d Way=%0d", set, way),
      UVM_HIGH)

    //--------------------------------------------
    // RELEASE LOCK
    //--------------------------------------------
    scb_write_locked       = 0;
    scb_write_owner        = -1;
    scb_write_owner_set    = -1;
    scb_write_owner_way    = -1;
    scb_write_owner_is_hit = 0;
  end

endfunction
v
