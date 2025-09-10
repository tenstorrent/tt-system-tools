use std::path::Path;
use std::time::SystemTime;
use std::fs;
use std::io;

pub const TT_SYS_DIR: &str = "/sys/class/tenstorrent";

// Tenstorrent device attribute struct
// Keeping all attributes as Strings for now
pub struct TTDevice {
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
    pub telemetry: Option<Telemetry>,
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

pub struct Telemetry {
    pub current: u32,
    pub power: u32,
    pub asic_temp: u32,
    pub vcore: u32,
    pub fan_rpm: u32,
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

impl TTDevice {
    fn from_dir(path: &Path) -> io::Result<Self> {
        Ok(Self {
            timestamp: Some(SystemTime::now()),
            tt_aiclk: sysfs_read_to_string(&path.join("tt_aiclk")).ok(),
            tt_arcclk: sysfs_read_to_string(&path.join("tt_arcclk")).ok(),
            tt_asic_id: sysfs_read_to_string(&path.join("tt_asic_id")).ok(),
            tt_axiclk: sysfs_read_to_string(&path.join("tt_axiclk")).ok(),
            tt_card_type: sysfs_read_to_string(&path.join("tt_card_type")).ok(),
            tt_fw_bundle_ver: sysfs_read_to_string(&path.join("tt_fw_bundle_ver")).ok(),
            tt_m3app_fw_ver: sysfs_read_to_string(&path.join("tt_m3app_fw_ver")).ok(),
            tt_serial: sysfs_read_to_string(&path.join("tt_serial")).ok(),
            pcie_perf_counters: PciePerfCounters::from_dir(&path.join("pcie_perf_counters")).ok(),
            telemetry: Telemetry::from_dir(path).ok(),
        })
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

impl Telemetry {
    fn from_dir(path: &Path) -> io::Result<Self> {
        const HWMON_PATH: &str = "device/hwmon/hwmon2/"; // TODO: is it always hwmon2
        let base_path = path.join(HWMON_PATH);
        let instance = Self {
            current: sysfs_read_to_u32(&base_path.join("curr1_input"))?,
            power: sysfs_read_to_u32(&base_path.join("power1_input"))?,
            asic_temp: sysfs_read_to_u32(&base_path.join("temp1_input"))?,
            vcore: sysfs_read_to_u32(&base_path.join("in0_input"))?,
            fan_rpm: sysfs_read_to_u32(&base_path.join("fan1_input"))?,
        };

        Ok(instance)
    }
}

pub fn get_tenstorrent_devices() -> io::Result<Vec<TTDevice>>  {
    let mut devices = Vec::new();

    for entry in fs::read_dir(TT_SYS_DIR)? {
        devices.push(TTDevice::from_dir(&entry?.path())?);
    }
    
    Ok(devices)
}