use std::fs::read_dir;
use std::io;

pub const TENSTORRENT_SYS_DIR: &str = "/sys/class/tenstorrent";

// Struct of sysfs and hwmon attributes
pub struct TenstorrentDevice {
    pub tt_aiclk: u32,
    pub tt_arcclk: u32,
    pub tt_asic_id: u32,
    pub tt_axiclk: u32,
    pub tt_card_type: u32,
    pub tt_fw_bundle_ver: u32,
    pub tt_m3app_fw_ver: u32,
    pub tt_serial: u32,
    // pub pcie_perf_counters: PciePerfCounters,

}

pub struct PciePerfCounters {
    pub mst_nonposted_wr_data_word_sent0: u32,
    pub mst_posted_wr_data_word_sent1: u32,
    pub slv_nonposted_wr_data_word_received0: u32,
    pub slv_posted_wr_data_word_received1: u32,
    pub mst_nonposted_wr_data_word_sent1: u32,
    pub mst_rd_data_word_received0: u32,
    pub slv_nonposted_wr_data_word_received1: u32,
    pub slv_rd_data_word_sent0: u32,
    pub mst_posted_wr_data_word_sent0: u32,
    pub mst_rd_data_word_received1: u32,
    pub slv_posted_wr_data_word_received0: u32,
    pub slv_rd_data_word_sent1: u32,
}

// Grab sysfs tenstorrent devices
pub fn get_tenstorrent_sysfs_dirs() -> Result<(), io::Error>  {
    for entry in read_dir(TENSTORRENT_SYS_DIR)? {
        println!("{}", entry?.path().display());
    }
    Ok(())
}

fn main() {
   let _ = get_tenstorrent_sysfs_dirs();
   // For dev in devices
   let dev_info = TenstorrentDevice {
        tt_aiclk: 0,
        tt_arcclk: 0,
        tt_asic_id: 0,
        tt_axiclk: 0,
        tt_card_type: 0,
        tt_fw_bundle_ver: 0,
        tt_m3app_fw_ver: 0,
        tt_serial: 0,
   };
   println!("{}", dev_info.tt_aiclk);
}
