//=============================================================================
// FILE: axi4_scoreboard_cache.sv
// CONTAINS: All L3 cache model functions and MSHR management
//   - axi_decode_cache_policy
//   - l3_cache_decode_address
//   - l3_cache_lookup
//   - l3_find_lru_way
//   - l3_update_lru
//   - l3_set_line_state
//   - l3_writeback_to_memory
//   - line_under_refill
//   - line_has_active_mshr
//   - get_line_base_addr
//   - scb_find_existing_mshr
//   - scb_allocate_mshr
//   - scb_update_mshr_beat
//   - scb_update_mshr_write_data
//   - apply_write_merge  (package-scope helper)
//   - scb_release_mshr
// Included by axi4_scoreboard.sv — NOT a standalone compilation unit
//=============================================================================

//=============================================================================
// Function: axi_decode_cache_policy
//=============================================================================
function axi_cache_policy_s axi4_scoreboard::axi_decode_cache_policy(
  bit [3:0] axcache,
  bit is_read
);

  axi_cache_policy_s p;
  p = '{default:0};

  p.bufferable = axcache[0];
  p.modifiable = axcache[1];

  // DEVICE MEMORY
  if(axcache == 4'b0000 || axcache == 4'b0001) begin
    p.device     = 1;
    p.modifiable = 0;
    return p;
  end

  // NON CACHEABLE NORMAL
  if(axcache[3:2] == 2'b00) begin
    p.cacheable = 0;
    return p;
  end

  p.cacheable = 1;

  // CACHE TYPE (PATTERN BASED)
  case(axcache)
    // WRITE THROUGH
    4'b1010, 4'b0110, 4'b1110:
      p.write_through = 1;

    // WRITE BACK
    4'b1011, 4'b0111, 4'b1111:
      p.write_back = 1;
  endcase

  // ALLOCATION (CHANNEL AWARE)
  if(is_read) begin
    p.read_allocate  = axcache[2];
  end
  else begin
    p.write_allocate = axcache[3];
  end

  return p;

endfunction : axi_decode_cache_policy


//=============================================================================
// Function: l3_cache_decode_address
//=============================================================================
function void axi4_scoreboard::l3_cache_decode_address(
  input  bit [ADDR_WIDTH-1:0] addr,
  output bit [L3_TAG_BITS-1:0] tag,
  output bit [L3_INDEX_BITS-1:0] index,
  output bit [L3_OFFSET_BITS-1:0] offset);

  offset = addr[L3_OFFSET_BITS-1:0];
  index  = addr[L3_OFFSET_BITS +: L3_INDEX_BITS];
  tag    = addr[L3_OFFSET_BITS + L3_INDEX_BITS +: L3_TAG_BITS];

endfunction : l3_cache_decode_address

//=============================================================================
// Function: l3_cache_lookup 
//Detects cache hits while blocking:
//   - Lines under refill
//   - Lines being written by locked master 
//=============================================================================
function bit axi4_scoreboard::l3_cache_lookup(
  input  bit [ADDR_WIDTH-1:0] addr,
  input  axi_cache_policy_s    policy,
  output int                   hit_way,
  output l3_state_e            state);
  bit [L3_TAG_BITS-1:0]   tag;
  bit [L3_INDEX_BITS-1:0] index;
  bit [L3_OFFSET_BITS-1:0] offset;

  // Default outputs
  hit_way = -1;
  state   = L3_INVALID;

  // AXI4 RULE — Device or Non-cacheable bypass
  if(policy.device || !policy.cacheable)
    return 0;

  // AXI4 RULE — no lookup if allocate bits = 00
  if(!policy.read_allocate && !policy.write_allocate)
    return 0;

  // Address decode
  l3_cache_decode_address(addr, tag, index, offset);

  // Block lookup if line is under refill
  if(line_under_refill(index, tag)) begin
    `uvm_info("L3_LOOKUP_BLOCK", 
      $sformatf("Blocked lookup - line under refill: idx=%0d tag=0x%0h", index, tag), 
      UVM_HIGH)
    return 0;
  end

  // Search set
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_cache[index][w].valid &&
       l3_cache[index][w].state != L3_FILLING &&
       l3_cache[index][w].state != L3_INVALID &&
       l3_cache[index][w].tag   == tag) begin

      //Block read hit if write-locked on same line
      if(scb_write_locked && 
         scb_write_owner_is_hit &&
         scb_write_owner_set == index &&
         scb_write_owner_way == w) begin
        `uvm_info("L3_LOOKUP_BLOCK", 
          $sformatf("Blocked read hit - write locked: idx=%0d way=%0d owner=M%0d", 
                    index, w, scb_write_owner), 
          UVM_HIGH)
        return 0; // Treat as miss to match RTL behavior
      end

      hit_way = w;
      state   = l3_cache[index][w].state;
      return 1;
    end
  end

  return 0;

endfunction : l3_cache_lookup

//=============================================================================
// Function: l3_find_lru_way
//Lower number = OLDER
//Higher number = NEWER
//=============================================================================
function int axi4_scoreboard::l3_find_lru_way(int set_index);
  int victim_way = -1;
  int max_lru    = -1;

  // Prefer INVALID ways (fast allocation, no eviction)
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_cache[set_index][w].state == L3_INVALID) begin
      return w;
    end
  end

  // Choose true LRU among CLEAN/DIRTY, NEVER select FILLING ways
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_cache[set_index][w].state != L3_FILLING && !line_has_active_mshr(set_index, w)) begin
      if(l3_lru_counter[set_index][w] > max_lru) begin
        max_lru    = l3_lru_counter[set_index][w];
        victim_way = w;
      end
    end
  end

  // DUT safety fallback (pipeline saturation)
  if(victim_way == -1) begin
    `uvm_warning("L3_LRU",
      $sformatf("All ways filling in set %0d — forcing way0 (DUT fallback)", set_index))
    victim_way = 0;
  end

  return victim_way;

endfunction : l3_find_lru_way

//=============================================================================
// Function: l3_update_lru (matches RTL age-based LRU)
//=============================================================================
function void axi4_scoreboard::l3_update_lru(int set_index, int way);

  // Don't update invalid or filling lines
  if(l3_cache[set_index][way].state == L3_INVALID ||
     l3_cache[set_index][way].state == L3_FILLING)
    return;

  // Increment all counters in set (aging) - matches RTL
  for(int w = 0; w < L3_CACHE_ASSOCIATIVITY; w++) begin
    if(l3_lru_counter[set_index][w] < 255) begin // 8-bit wrap like RTL
      l3_lru_counter[set_index][w]++;
    end
  end

  // Reset accessed way to 0 (most recently used)
  l3_lru_counter[set_index][way] = 0;

endfunction : l3_update_lru

//=============================================================================
// Function: l3_set_line_state
//=============================================================================
function void axi4_scoreboard::l3_set_line_state(
  input int set_index,
  input int way,
  input l3_state_e new_state);

  l3_cache[set_index][way].state = new_state;

  // Maintain valid bit
  if(new_state == L3_INVALID)
    l3_cache[set_index][way].valid = 0;
  else
    l3_cache[set_index][way].valid = 1;

endfunction : l3_set_line_state

//=============================================================================
// Function: l3_writeback_to_memory 
//=============================================================================
function void axi4_scoreboard::l3_writeback_to_memory(
  input int set_index,
  input int way
);

  bit [ADDR_WIDTH-1:0] wb_addr;
  int                  slave_idx;
  int                  word_i;
  int                  lane;

  // ── Only write back if the line is actually dirty ─────────────────────────
  if(l3_cache[set_index][way].state != L3_DIRTY) begin
    `uvm_info("L3_WB_SKIP",
      $sformatf("Skipping writeback: Set=%0d Way=%0d State=%s — not dirty",
                set_index, way, l3_cache[set_index][way].state.name()),
      UVM_HIGH)
    return;
  end

  // ── Reconstruct the cache line base address from tag + index ─────────────
  // Matches DUT:  s_awaddr[sid] = {tag_array[idx][way], idx, {OFFSET_BITS{1'b0}}}
  wb_addr = { l3_cache[set_index][way].tag,
              set_index[L3_INDEX_BITS-1:0],
              {L3_OFFSET_BITS{1'b0}} };

  // ── Validate the address maps to a slave ─────────────────────────────────
  slave_idx = get_slave_index(wb_addr);
  if(slave_idx == -1) begin
    `uvm_error("L3_WB_NO_SLAVE",
      $sformatf("Writeback addr=0x%0h maps to no slave — Set=%0d Way=%0d",
                wb_addr, set_index, way))
    return;
  end

  `uvm_info("L3_WB_START",
    $sformatf("Writeback: Set=%0d Way=%0d Addr=0x%0h Slave=%0d",
              set_index, way, wb_addr, slave_idx),
    UVM_MEDIUM)

  // ── Flush dirty bytes to referenceData[] ─────────────────────────────────

  for(int byte_i = 0; byte_i < L3_CACHE_LINE_SIZE_BYTES; byte_i++) begin
    word_i = byte_i / (DATA_WIDTH/8);
    lane   = byte_i % (DATA_WIDTH/8);
    referenceData[slave_idx][wb_addr + byte_i] =
      l3_cache[set_index][way].data[word_i][8*lane +: 8];
  end

  l3_set_line_state(set_index, way, L3_CLEAN);

  l3_writebacks_to_memory++;

  `uvm_info("L3_WB_FLUSHED",
    $sformatf("Dirty line flushed to refMem: Set=%0d Way=%0d Addr=0x%0h "
              "Slave=%0d — awaiting BRESP",
              set_index, way, wb_addr, slave_idx),
    UVM_MEDIUM)

endfunction : l3_writeback_to_memory

//=============================================================================
// Function: line_under_refill 
//=============================================================================
function bit axi4_scoreboard::line_under_refill(input int index, input int tag);
  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid &&
       !scb_mshr[i].done &&
       scb_mshr[i].index == index &&
       scb_mshr[i].tag == tag)
      return 1;
  end
  return 0;
endfunction : line_under_refill

//=============================================================================
// Function: line_has_active_mshr
//=============================================================================
function bit axi4_scoreboard::line_has_active_mshr(input int index, input int way);
  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid &&
       scb_mshr[i].index == index &&
       scb_mshr[i].way == way)
      return 1;
  end
  return 0;
endfunction : line_has_active_mshr

//=============================================================================
// Function: get_line_base_addr
//=============================================================================
function bit[ADDR_WIDTH-1:0] axi4_scoreboard::get_line_base_addr(
  bit[ADDR_WIDTH-1:0] addr);
  return {addr[ADDR_WIDTH-1:L3_OFFSET_BITS], {L3_OFFSET_BITS{1'b0}}};
endfunction : get_line_base_addr

//=============================================================================
// Function: scb_find_existing_mshr
//=============================================================================
function int axi4_scoreboard::scb_find_existing_mshr(
    input logic [ADDR_WIDTH-1:0] addr);

   logic [ADDR_WIDTH-1:0] line_base;
   line_base = get_line_base_addr(addr);

   for(int i=0;i<MAX_MSHR;i++) begin
      if(scb_mshr[i].valid &&
         !scb_mshr[i].done &&
         scb_mshr[i].line_addr == line_base)
         return i;
   end

   return -1;
endfunction: scb_find_existing_mshr

//=============================================================================
// Function: scb_allocate_mshr
//=============================================================================
function int axi4_scoreboard::scb_allocate_mshr(
    input logic [ADDR_WIDTH-1:0] addr,
    input int                    master,
    input int                    txn_id,
    input bit                    is_write);

  int                      idx;
  int                      slave;
  int                      way;
  bit [L3_TAG_BITS-1:0]    tag;
  bit [L3_INDEX_BITS-1:0]  index;
  bit [L3_OFFSET_BITS-1:0] offset;
  logic [ADDR_WIDTH-1:0]   line_base;

  idx = scb_find_existing_mshr(addr);
  if(idx != -1) begin
    `uvm_info("L3_MSHR_MERGE",
              $sformatf("Merging request for line 0x%0h into existing MSHR[%0d]",
                        addr, idx),
              UVM_MEDIUM)
    return idx;
  end

  l3_cache_decode_address(addr, tag, index, offset);
  way       = l3_find_lru_way(index);
  slave     = get_slave_index(addr);
  line_base = get_line_base_addr(addr);

  if(slave == -1) begin
    `uvm_error("MSHR_ALLOC", $sformatf("No slave mapped for addr=0x%0h", addr))
    return -1;
  end

  if(active_r_valid[slave])
    return -1;

  for(int i = 0; i < MAX_MSHR; i++) begin
    if(!scb_mshr[i].valid) begin

      scb_mshr[i].needs_writeback =
        (l3_cache[index][way].valid &&
         l3_cache[index][way].state == L3_DIRTY);

      scb_mshr[i].valid       = 1;
      scb_mshr[i].done        = 0;
      scb_mshr[i].ar_sent     = 0;
      scb_mshr[i].wb_done     = !scb_mshr[i].needs_writeback;
      scb_mshr[i].line_addr   = line_base;
      scb_mshr[i].master      = master;
      scb_mshr[i].txn_id      = txn_id;
      scb_mshr[i].is_write    = is_write;   
      scb_mshr[i].slave       = slave;
      scb_mshr[i].index       = index;
      scb_mshr[i].way         = way;
      scb_mshr[i].tag         = tag;
      scb_mshr[i].beat_count  = 0;
      scb_mshr[i].wbeat_count = 0;
      scb_mshr[i].resp_code   = 2'b00;
      scb_mshr[i].wb_error    = 0;

      if(scb_mshr[i].needs_writeback)
        l3_writeback_to_memory(index, way);

      l3_set_line_state(index, way, L3_FILLING);

      `uvm_info("L3_MSHR_ALLOC",
        $sformatf("MSHR[%0d] M[%0d] Addr=0x%0h Idx=%0d Way=%0d IsWrite=%0b NeedsWB=%0b",
                  i, master, addr, index, way,
                  is_write, scb_mshr[i].needs_writeback),
        UVM_MEDIUM)

      return i;
    end
  end

  `uvm_warning("MSHR_FULL", $sformatf("All MSHRs busy for addr=0x%0h", addr))
  return -1;

endfunction : scb_allocate_mshr

//=============================================================================
// Function: scb_update_mshr_beat
//=============================================================================
function void axi4_scoreboard::scb_update_mshr_beat(
    input int slave,
    input logic [DATA_WIDTH-1:0] data,  
    input bit rlast);

   if(!active_r_valid[slave]) return;

   int i = active_r_mshr[slave];

   if(!scb_mshr[i].valid) return;
   if(scb_mshr[i].beat_count >= WORDS_PER_LINE) return;

   for(int b = 0; b < AXI_DATA_BYTES; b++) begin
     int byte_offset = scb_mshr[i].beat_count * AXI_DATA_BYTES + b;
     
     if(byte_offset < L3_CACHE_LINE_SIZE_BYTES) begin
       l3_cache[scb_mshr[i].index][scb_mshr[i].way].data[byte_offset] = 
         data[8*b +: 8];
     end
   end

   scb_mshr[i].beat_count++;

   if(rlast)
      scb_mshr[i].done = 1;
      
      `uvm_info("MSHR_REFILL_DONE",
        $sformatf("MSHR[%0d] refill complete: Beats=%0d Index=%0d Way=%0d",
                  i, scb_mshr[i].beat_count, scb_mshr[i].index, scb_mshr[i].way),
        UVM_HIGH)

endfunction : scb_update_mshr_beat

//=============================================================================
// Function: scb_update_mshr_write_data 
//=============================================================================
function void axi4_scoreboard::scb_update_mshr_write_data(
    input int                        master,
    input int                        txn_id,
    input logic [DATA_WIDTH-1:0]     data,
    input logic [(DATA_WIDTH/8)-1:0] strb);

  int b; 

  for(int i = 0; i < MAX_MSHR; i++) begin
    if(scb_mshr[i].valid    &&
       scb_mshr[i].is_write &&      
       scb_mshr[i].master == master &&
       scb_mshr[i].txn_id == txn_id &&
       !scb_mshr[i].done) begin

      b = scb_mshr[i].wbeat_count; 

      if(b < WORDS_PER_LINE) begin
        scb_mshr[i].wdata_buf[b] = data;
        scb_mshr[i].wstrb_buf[b] = strb;
        scb_mshr[i].wbeat_count++;
      end else begin
        `uvm_warning("MSHR_WDATA_OVERFLOW",
          $sformatf("MSHR[%0d] wbeat_count=%0d >= WORDS_PER_LINE=%0d",
                    i, b, WORDS_PER_LINE))
      end

    end
  end

endfunction : scb_update_mshr_write_data

//=============================================================================
// Function: apply_write_merge
// Word-local merge with byte offset support
//=============================================================================
function void apply_write_merge(
      inout logic [DATA_W-1:0] line_data,
      input  logic [DATA_W-1:0] wdata,
      input  logic [STRB_W-1:0] wstrb);

  if(STRB_W*8 != DATA_W)
   `uvm_error("MERGE","WSTRB width mismatch")

   for(int b = 0; b < STRB_W; b++) begin
      if(wstrb[b]) begin
         line_data[b*8 +: 8] = wdata[b*8 +: 8];
      end
   end

endfunction:apply_write_merge

//=============================================================================
// Function: scb_release_mshr
//=============================================================================
function void axi4_scoreboard::scb_release_mshr(
    input int i,
    input bit resp_accepted);

   if(i < 0 || i >= MAX_MSHR)
      return;

   if(!scb_mshr[i].valid)
      return;

   if(!scb_mshr[i].done)
      return;

   if(!resp_accepted)
      return;

   int set  = scb_mshr[i].index;  
   int way  = scb_mshr[i].way;
   int base = scb_mshr[i].start_word;

   // Apply buffered writes after refill
   for(int b = 0; b < scb_mshr[i].wbeat_count; b++) begin
      int line_word = base + b;
      if(line_word >= WORDS_PER_LINE)
         break;

      apply_write_merge(
         l3_cache[set][way].data[line_word],
         scb_mshr[i].wdata_buf[b],
         scb_mshr[i].wstrb_buf[b]);
   end

   // Update line state
   if(scb_mshr[i].wbeat_count > 0)
      l3_set_line_state(set, way, L3_DIRTY);
   else
      l3_set_line_state(set, way, L3_CLEAN);

   // UPDATE LRU ON SUCCESSFUL COMPLETION
   if(scb_mshr[i].resp_code == 2'b00) begin
     l3_update_lru(set, way);
   end

   // Release slave refill ownership
   int s = scb_mshr[i].slave;
   if(s >= 0 && s < NO_OF_SLAVES) begin
      active_r_valid[s] = 0;
      active_r_mshr[s]  = -1;
   end

   scb_mshr[i] = '{default:0};

endfunction : scb_release_mshr
