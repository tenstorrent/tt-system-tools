use std::path::Path;
use std::fs;
use std::io;

pub const TENSTORRENT_SYS_DIR: &str = "/sys/class/tenstorrent";

// Struct of attributes and hwmon
// Keeping all the attributes as Strings for now
pub struct TenstorrentDevice {
    pub tt_aiclk: Option<String>,
    pub tt_arcclk: Option<String>,
    pub tt_asic_id: Option<String>,
    pub tt_axiclk: Option<String>,
    pub tt_card_type: Option<String>,
    pub tt_fw_bundle_ver: Option<String>,
    pub tt_m3app_fw_ver: Option<String>,
    pub tt_serial: Option<String>,
    pub pcie_perf_counters: Option<PciePerfCounters>,
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

fn sysfs_read_to_u32(path: &Path) -> io::Result<u32> {
    let content = fs::read_to_string(&path)?;
    let content_trim = &content.trim();
    u32::from_str_radix(content_trim, 16).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
}

fn sysfs_read_to_u64(path: &Path) -> io::Result<u64> {
    let content = fs::read_to_string(&path)?;
    let content_trim = &content.trim();
    u64::from_str_radix(content_trim, 16).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
}

fn sysfs_read_to_string(path: &Path) -> io::Result<String> {
    let content = fs::read_to_string(&path)?;
    Ok(content.trim().to_string())
}

impl TenstorrentDevice {
    fn default() -> Self {
        Self {
            tt_aiclk: None,
            tt_arcclk: None,
            tt_asic_id: None,
            tt_axiclk: None,
            tt_card_type: None,
            tt_fw_bundle_ver: None,
            tt_m3app_fw_ver: None,
            tt_serial: None,
            pcie_perf_counters: None,
        }
    }

    fn from_dir(path: &Path) -> io::Result<Self> {
        let mut instance = Self::default();

        for entry in fs::read_dir(&path)? {
            let entry = entry?;
            let file_name = entry.file_name();
            let file_name_str = file_name.to_string_lossy();
            let file_path = entry.path();

            match file_name_str.as_ref() {
                "tt_aiclk" => instance.tt_aiclk =  Some(sysfs_read_to_string(&file_path)?),
                "tt_arcclk" => instance.tt_arcclk =  Some(sysfs_read_to_string(&file_path)?),
                "tt_asic_id" => instance.tt_asic_id =  Some(sysfs_read_to_string(&file_path)?),
                "tt_axiclk" => instance.tt_axiclk =  Some(sysfs_read_to_string(&file_path)?),
                "tt_card_type" => instance.tt_card_type = Some(sysfs_read_to_string(&file_path)?),
                "tt_fw_bundle_ver" => instance.tt_fw_bundle_ver =  Some(sysfs_read_to_string(&file_path)?),
                "tt_m3app_fw_ver" => instance.tt_m3app_fw_ver =  Some(sysfs_read_to_string(&file_path)?),
                "tt_serial" => instance.tt_serial =  Some(sysfs_read_to_string(&file_path)?),
                _ => (), // Ignore unknown files
            }
        }

        Ok(instance)
    }
}

// Grab sysfs tenstorrent devices
pub fn get_tenstorrent_sysfs_dirs() -> io::Result<()>  {
    for entry in fs::read_dir(TENSTORRENT_SYS_DIR)? {
        let instance = TenstorrentDevice::from_dir(&entry?.path())?;
        println!("{:?}", instance.tt_card_type);
        println!("{:?}", instance.tt_axiclk);
        println!("{:?}", instance.tt_asic_id);
    }
    Ok(())
}
