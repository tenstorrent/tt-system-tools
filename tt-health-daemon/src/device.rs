use std::path::Path;
use std::fs;
use std::io;
use chrono::{DateTime, Utc};

// Tenstorrent device attribute struct
// Keeping all attributes as Strings for now
#[derive(Debug)]
pub struct TTDevice {
    pub time: DateTime<Utc>,
    pub device_path: String,
    pub tt_aiclk: Option<String>,
    pub tt_arcclk: Option<String>,
    pub tt_asic_id: Option<String>,
    pub tt_axiclk: Option<String>,
    pub tt_card_type: Option<String>,
    pub tt_fw_bundle_ver: Option<String>,
    pub tt_m3app_fw_ver: Option<String>,
    pub tt_serial: Option<String>,
    pub pcie_perf_counters: PciePerfCounters,
    pub telemetry: Telemetry,
}

#[derive(Debug)]
pub struct PciePerfCounters {
    pub mst_nonposted_wr_data_word_sent0: Option<u32>,
    pub mst_nonposted_wr_data_word_sent1: Option<u32>,
    pub mst_posted_wr_data_word_sent0: Option<u32>,
    pub mst_posted_wr_data_word_sent1: Option<u32>,
    pub mst_rd_data_word_received0: Option<u32>,
    pub mst_rd_data_word_received1: Option<u32>,
    pub slv_nonposted_wr_data_word_received0: Option<u32>,
    pub slv_nonposted_wr_data_word_received1: Option<u32>,
    pub slv_posted_wr_data_word_received0: Option<u32>,
    pub slv_posted_wr_data_word_received1: Option<u32>,
    pub slv_rd_data_word_sent0: Option<u32>,
    pub slv_rd_data_word_sent1: Option<u32>,
}

#[derive(Debug)]
pub struct Telemetry {
    pub current: Option<u32>,
    pub power: Option<u32>,
    pub asic_temp: Option<u32>,
    pub vcore: Option<u32>,
    pub fan_rpm: Option<u32>,
}

fn sysfs_read_to_u32(path: &Path) -> Option<u32> {
    let content = fs::read_to_string(&path).ok()?;
    let content_trim = content.trim();
    u32::from_str_radix(content_trim, 10).ok()
}

fn sysfs_read_to_string(path: &Path) -> Option<String> {
    let content = fs::read_to_string(&path).ok()?;
    Some(content.trim().to_string()) // Trim \n from the end
}

impl TTDevice {
    pub fn new(path: &Path) -> Self {
        Self {
            device_path: path.to_string_lossy().to_string(),
            time: Utc::now(),
            tt_aiclk: None,
            tt_arcclk: None,
            tt_asic_id: None,
            tt_axiclk: None,
            tt_card_type: None,
            tt_fw_bundle_ver: None,
            tt_m3app_fw_ver: None,
            tt_serial: None,
            pcie_perf_counters: PciePerfCounters::new(),
            telemetry: Telemetry::new(),
        }
    }

    pub fn update(&mut self) -> io::Result<()> {
        let path = Path::new(&self.device_path);
        self.time = Utc::now();
        self.tt_aiclk = sysfs_read_to_string(&path.join("tt_aiclk"));
        self.tt_arcclk = sysfs_read_to_string(&path.join("tt_arcclk"));
        self.tt_asic_id = sysfs_read_to_string(&path.join("tt_asic_id"));
        self.tt_axiclk = sysfs_read_to_string(&path.join("tt_axiclk"));
        self.tt_card_type = sysfs_read_to_string(&path.join("tt_card_type"));
        self.tt_fw_bundle_ver = sysfs_read_to_string(&path.join("tt_fw_bundle_ver"));
        self.tt_m3app_fw_ver = sysfs_read_to_string(&path.join("tt_m3app_fw_ver"));
        self.tt_serial = sysfs_read_to_string(&path.join("tt_serial"));
        self.pcie_perf_counters.update_from_dir(&path.join("pcie_perf_counters"));
        self.telemetry.update_from_dir(&path.join("device/hwmon/hwmon2/")); // TODO: which paths to inspect
        Ok(())
    }
}

impl PciePerfCounters {
    pub fn new() -> Self {
        Self {
            mst_nonposted_wr_data_word_sent0: None,
            mst_nonposted_wr_data_word_sent1: None,
            mst_posted_wr_data_word_sent0: None,
            mst_posted_wr_data_word_sent1: None,
            mst_rd_data_word_received0: None,
            mst_rd_data_word_received1: None,
            slv_nonposted_wr_data_word_received0: None,
            slv_nonposted_wr_data_word_received1: None,
            slv_posted_wr_data_word_received0: None,
            slv_posted_wr_data_word_received1: None,
            slv_rd_data_word_sent0: None,
            slv_rd_data_word_sent1: None,
        }
    }

    pub fn update_from_dir(&mut self, path: &Path) {
        self.mst_nonposted_wr_data_word_sent0 = sysfs_read_to_u32(&path.join("mst_nonposted_wr_data_word_sent0"));
        self.mst_nonposted_wr_data_word_sent1 = sysfs_read_to_u32(&path.join("mst_nonposted_wr_data_word_sent1"));
        self.mst_posted_wr_data_word_sent0 = sysfs_read_to_u32(&path.join("mst_posted_wr_data_word_sent0"));
        self.mst_posted_wr_data_word_sent1 = sysfs_read_to_u32(&path.join("mst_posted_wr_data_word_sent1"));
        self.mst_rd_data_word_received0 = sysfs_read_to_u32(&path.join("mst_rd_data_word_received0"));
        self.mst_rd_data_word_received1 = sysfs_read_to_u32(&path.join("mst_rd_data_word_received1"));
        self.slv_nonposted_wr_data_word_received0 = sysfs_read_to_u32(&path.join("slv_nonposted_wr_data_word_received0"));
        self.slv_nonposted_wr_data_word_received1 = sysfs_read_to_u32(&path.join("slv_nonposted_wr_data_word_received1"));
        self.slv_posted_wr_data_word_received0 = sysfs_read_to_u32(&path.join("slv_posted_wr_data_word_received0"));
        self.slv_posted_wr_data_word_received1 = sysfs_read_to_u32(&path.join("slv_posted_wr_data_word_received1"));
        self.slv_rd_data_word_sent0 = sysfs_read_to_u32(&path.join("slv_rd_data_word_sent0"));
        self.slv_rd_data_word_sent1 = sysfs_read_to_u32(&path.join("slv_rd_data_word_sent1"));
    }
}

impl Telemetry {
    pub fn new() -> Self {
        Self {
            current: None,
            power: None,
            asic_temp: None,
            vcore: None,
            fan_rpm: None,
        }
    }

    pub fn update_from_dir(&mut self, path: &Path) {
        self.current = sysfs_read_to_u32(&path.join("curr1_input"));
        self.power = sysfs_read_to_u32(&path.join("power1_input"));
        self.asic_temp = sysfs_read_to_u32(&path.join("temp1_input"));
        self.vcore = sysfs_read_to_u32(&path.join("in0_input"));
        self.fan_rpm = sysfs_read_to_u32(&path.join("fan1_input"));
    }
}

pub fn get_tenstorrent_devices() -> io::Result<Vec<TTDevice>> {
    let mut devices = Vec::new();

    for entry in fs::read_dir("/sys/class/tenstorrent")? {
        let path = entry?.path();
        let device = TTDevice::new(&path);
        devices.push(device);
    }
    
    Ok(devices)
}

pub fn update_tenstorrent_devices(devices: &mut [TTDevice]) -> io::Result<()> {
    for device in devices {
        device.update()?;
    }
    Ok(())
}
