use std::path::Path;
use std::time::SystemTime;
use std::fs;
use std::io;

pub const TENSTORRENT_SYS_DIR: &str = "/sys/class/tenstorrent";

// Tenstorrent device attribute struct
// Keeping all attributes as Strings for now
pub struct TenstorrentDevice {
    pub timestamp: Option<SystemTime>,
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
    pub mst_nonposted_wr_data_word_sent1: u32,
    pub mst_posted_wr_data_word_sent0: u32,
    pub mst_posted_wr_data_word_sent1: u32,
    pub mst_rd_data_word_received0: u32,
    pub mst_rd_data_word_received1: u32,
    pub slv_nonposted_wr_data_word_received0: u32,
    pub slv_nonposted_wr_data_word_received1: u32,
    pub slv_posted_wr_data_word_received0: u32,
    pub slv_posted_wr_data_word_received1: u32,
    pub slv_rd_data_word_sent0: u32,
    pub slv_rd_data_word_sent1: u32,
}

fn sysfs_read_to_u32(path: &Path) -> io::Result<u32> {
    let content = fs::read_to_string(&path)?;
    let content_trim = &content.trim();
    u32::from_str_radix(content_trim, 10).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
}

fn sysfs_read_to_string(path: &Path) -> io::Result<String> {
    let content = fs::read_to_string(&path)?;
    Ok(content.trim().to_string())
}

impl TenstorrentDevice {
    fn default() -> Self {
        Self {
            timestamp: None,
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
            let file_name_str = entry.file_name();
            let file_path = entry.path();

            match file_name_str.to_string_lossy().as_ref() {
                "tt_aiclk" => instance.tt_aiclk =  Some(sysfs_read_to_string(&file_path)?),
                "tt_arcclk" => instance.tt_arcclk =  Some(sysfs_read_to_string(&file_path)?),
                "tt_asic_id" => instance.tt_asic_id =  Some(sysfs_read_to_string(&file_path)?),
                "tt_axiclk" => instance.tt_axiclk =  Some(sysfs_read_to_string(&file_path)?),
                "tt_card_type" => instance.tt_card_type = Some(sysfs_read_to_string(&file_path)?),
                "tt_fw_bundle_ver" => instance.tt_fw_bundle_ver =  Some(sysfs_read_to_string(&file_path)?),
                "tt_m3app_fw_ver" => instance.tt_m3app_fw_ver =  Some(sysfs_read_to_string(&file_path)?),
                "tt_serial" => instance.tt_serial =  Some(sysfs_read_to_string(&file_path)?),
                "pcie_perf_counters" => instance.pcie_perf_counters = Some(PciePerfCounters::from_dir(&file_path)?),
                _ => (), // Ignore unknown values
            }
        }

        instance.timestamp = Some(SystemTime::now());

        Ok(instance)
    }
}

impl PciePerfCounters {
    fn from_dir(path: &Path) -> io::Result<Self> {
        let instance = Self {
            mst_nonposted_wr_data_word_sent0: sysfs_read_to_u32(&path.join("mst_nonposted_wr_data_word_sent0"))?,
            mst_nonposted_wr_data_word_sent1: sysfs_read_to_u32(&path.join("mst_nonposted_wr_data_word_sent1"))?,
            mst_posted_wr_data_word_sent0: sysfs_read_to_u32(&path.join("mst_posted_wr_data_word_sent0"))?,
            mst_posted_wr_data_word_sent1: sysfs_read_to_u32(&path.join("mst_posted_wr_data_word_sent1"))?,
            mst_rd_data_word_received0: sysfs_read_to_u32(&path.join("mst_rd_data_word_received0"))?,
            mst_rd_data_word_received1: sysfs_read_to_u32(&path.join("mst_rd_data_word_received1"))?,
            slv_nonposted_wr_data_word_received0: sysfs_read_to_u32(&path.join("slv_nonposted_wr_data_word_received0"))?,
            slv_nonposted_wr_data_word_received1: sysfs_read_to_u32(&path.join("slv_nonposted_wr_data_word_received1"))?,
            slv_posted_wr_data_word_received0: sysfs_read_to_u32(&path.join("slv_posted_wr_data_word_received0"))?,
            slv_posted_wr_data_word_received1: sysfs_read_to_u32(&path.join("slv_posted_wr_data_word_received1"))?,
            slv_rd_data_word_sent0: sysfs_read_to_u32(&path.join("slv_rd_data_word_sent0"))?,
            slv_rd_data_word_sent1: sysfs_read_to_u32(&path.join("slv_rd_data_word_sent1"))?
        };

        Ok(instance)
    }
}

pub fn get_tenstorrent_devices() -> io::Result<Vec<TenstorrentDevice>>  {
    let mut devices = Vec::new();

    for entry in fs::read_dir(TENSTORRENT_SYS_DIR)? {
        devices.push(TenstorrentDevice::from_dir(&entry?.path())?);
    }
    
    Ok(devices)
}
