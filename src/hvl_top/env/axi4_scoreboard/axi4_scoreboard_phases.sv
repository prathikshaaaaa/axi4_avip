

function axi4_scorebaord::new(string name = "axi4_scoreboard", 
                                       uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//=============================================================================
// Function: build_phase
//=============================================================================
function void axi4_scorebaord::build_phase(uvm_phase phase);
  super.build_phase(phase);
  
  if(!uvm_config_db#(axi4_env_config)::get(this, "", "axi4_env_config", axi4_env_cfg_h)) begin
    `uvm_fatal("FATAL_ENV_CONFIG", "Couldn't get axi4_env_config from config_db")
  end
  
  // Initialize L3 cache model
  init_l3_cache_model();
  
  // Allocate arrays for masters
  axi4_master_read_address_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_read_data_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_write_address_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_write_data_analysis_fifo = new[NO_OF_MASTERS];
  axi4_master_write_response_analysis_fifo = new[NO_OF_MASTERS];
  
  axi4_master_tx_awaddr_count = new[NO_OF_MASTERS];
  axi4_master_tx_wdata_count = new[NO_OF_MASTERS];
  axi4_master_tx_bresp_count = new[NO_OF_MASTERS];
  axi4_master_tx_araddr_count = new[NO_OF_MASTERS];
  axi4_master_tx_rdata_count = new[NO_OF_MASTERS];
  axi4_master_tx_rresp_count = new[NO_OF_MASTERS];
  
  l3_read_hits_per_master = new[NO_OF_MASTERS];
  l3_read_misses_per_master = new[NO_OF_MASTERS];
  l3_write_hits_per_master = new[NO_OF_MASTERS];
  l3_write_misses_per_master = new[NO_OF_MASTERS];
  
  foreach(l3_read_hits_per_master[i]) begin
    l3_read_hits_per_master[i] = 0;
    l3_read_misses_per_master[i] = 0;
    l3_write_hits_per_master[i] = 0;
    l3_write_misses_per_master[i] = 0;
    wr_hit_counted[i] = 0;
  end
  
  // Allocate arrays for slaves
  axi4_slave_read_address_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_read_data_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_write_address_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_write_data_analysis_fifo = new[NO_OF_SLAVES];
  axi4_slave_write_response_analysis_fifo = new[NO_OF_SLAVES];
  
  axi4_slave_tx_awaddr_count = new[NO_OF_SLAVES];
  axi4_slave_tx_wdata_count = new[NO_OF_SLAVES];
  axi4_slave_tx_bresp_count = new[NO_OF_SLAVES];
  axi4_slave_tx_araddr_count = new[NO_OF_SLAVES];
  axi4_slave_tx_rdata_count = new[NO_OF_SLAVES];
  axi4_slave_tx_rresp_count = new[NO_OF_SLAVES];
  
  axi4_slave_agent_cfg_h = new[NO_OF_SLAVES];
  SLAVE_START_ADDR = new[NO_OF_SLAVES];
  SLAVE_END_ADDR = new[NO_OF_SLAVES];
  
  // Create TLM FIFOs for each master
  foreach(axi4_master_read_address_analysis_fifo[i]) begin
    axi4_master_read_address_analysis_fifo[i] = new($sformatf("axi4_master_read_address_analysis_fifo[%0d]", i), this);
    axi4_master_read_data_analysis_fifo[i] = new($sformatf("axi4_master_read_data_analysis_fifo[%0d]", i), this);
    axi4_master_write_address_analysis_fifo[i] = new($sformatf("axi4_master_write_address_analysis_fifo[%0d]", i), this);
    axi4_master_write_data_analysis_fifo[i] = new($sformatf("axi4_master_write_data_analysis_fifo[%0d]", i), this);
    axi4_master_write_response_analysis_fifo[i] = new($sformatf("axi4_master_write_response_analysis_fifo[%0d]", i), this);
  end
  
  // Create TLM FIFOs for each slave
  foreach(axi4_slave_read_address_analysis_fifo[i]) begin
    axi4_slave_read_address_analysis_fifo[i] = new($sformatf("axi4_slave_read_address_analysis_fifo[%0d]", i), this);
    axi4_slave_read_data_analysis_fifo[i] = new($sformatf("axi4_slave_read_data_analysis_fifo[%0d]", i), this);
    axi4_slave_write_address_analysis_fifo[i] = new($sformatf("axi4_slave_write_address_analysis_fifo[%0d]", i), this);
    axi4_slave_write_data_analysis_fifo[i] = new($sformatf("axi4_slave_write_data_analysis_fifo[%0d]", i), this);
    axi4_slave_write_response_analysis_fifo[i] = new($sformatf("axi4_slave_write_response_analysis_fifo[%0d]", i), this);
    
    if(!uvm_config_db#(axi4_slave_agent_config)::get(this, "", $sformatf("axi4_slave_agent_config[%0d]", i), axi4_slave_agent_cfg_h[i])) begin
      `uvm_fatal("FATAL_SA_AGENT_CONFIG", $sformatf("Couldn't get axi4_slave_agent_config[%0d] from config_db", i))
    end
    
    SLAVE_START_ADDR[i] = axi4_slave_agent_cfg_h[i].min_address;
    SLAVE_END_ADDR[i] = axi4_slave_agent_cfg_h[i].max_address;
  end
  
  // Initialize Round-Robin tracking
  for(int s = 0; s < NO_OF_SLAVES; s++) begin
    rr_write_next_master[s] = 0;
    rr_write_last_granted[s] = -1;
    rr_read_next_master[s] = 0;
    rr_read_last_granted[s] = -1;
    
    for(int m = 0; m < NO_OF_MASTERS; m++) begin
      rr_write_pending_cnt[s][m] = 0;
      rr_read_pending_cnt[s][m] = 0;
    end
  end
  
endfunction : build_phase

//=============================================================================
// Function: connect_phase
//=============================================================================
function void axi4_scorebaord::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase
