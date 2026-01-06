use crate::device::{TTDevice, PciePerfCounters, Telemetry};
use chrono::{DateTime, Utc};
use influxdb::{WriteQuery, InfluxDbWriteable};

pub fn create_influxdb_query(device: TTDevice) -> WriteQuery {
    TTDeviceFlat::from(device).into_query("tenstorrent_metrics")
}

#[derive(InfluxDbWriteable)]
struct TTDeviceFlat {
    time: DateTime<Utc>,
    device_path: String,
    #[influxdb(tag)]
    tt_asic_id: Option<String>,
    tt_serial: Option<String>,
    tt_aiclk: Option<u32>,
    tt_arcclk: Option<u32>,
    tt_axiclk: Option<u32>,
    tt_card_type: Option<String>,
    tt_fw_bundle_ver: Option<String>,
    tt_m3app_fw_ver: Option<String>,
    // PciePerfCounters
    mst_nonposted_wr_data_word_sent0: Option<u32>,
    mst_nonposted_wr_data_word_sent1: Option<u32>,
    mst_posted_wr_data_word_sent0: Option<u32>,
    mst_posted_wr_data_word_sent1: Option<u32>,
    mst_rd_data_word_received0: Option<u32>,
    mst_rd_data_word_received1: Option<u32>,
    slv_nonposted_wr_data_word_received0: Option<u32>,
    slv_nonposted_wr_data_word_received1: Option<u32>,
    slv_posted_wr_data_word_received0: Option<u32>,
    slv_posted_wr_data_word_received1: Option<u32>,
    slv_rd_data_word_sent0: Option<u32>,
    slv_rd_data_word_sent1: Option<u32>,
    // Telemetry
    current: Option<u32>,
    power: Option<u32>,
    asic_temp: Option<u32>,
    vcore: Option<u32>,
    fan_rpm: Option<u32>,
}

impl From<TTDevice> for TTDeviceFlat {
    fn from(device: TTDevice) -> Self {
        let TTDevice { time, device_path, tt_aiclk, tt_arcclk, tt_asic_id, tt_axiclk, 
            tt_card_type, tt_fw_bundle_ver, tt_m3app_fw_ver, tt_serial, 
            pcie_perf_counters, telemetry } = device;
        let PciePerfCounters { mst_nonposted_wr_data_word_sent0, mst_nonposted_wr_data_word_sent1,
            mst_posted_wr_data_word_sent0, mst_posted_wr_data_word_sent1, mst_rd_data_word_received0,
            mst_rd_data_word_received1, slv_nonposted_wr_data_word_received0, slv_nonposted_wr_data_word_received1,
            slv_posted_wr_data_word_received0, slv_posted_wr_data_word_received1, slv_rd_data_word_sent0,
            slv_rd_data_word_sent1 } = pcie_perf_counters;
        let Telemetry { current, power, asic_temp, vcore, fan_rpm } = telemetry;
        Self {
            time, device_path, tt_asic_id, tt_serial, tt_aiclk, tt_arcclk, tt_axiclk, 
            tt_card_type, tt_fw_bundle_ver, tt_m3app_fw_ver, mst_nonposted_wr_data_word_sent0, mst_nonposted_wr_data_word_sent1,
            mst_posted_wr_data_word_sent0, mst_posted_wr_data_word_sent1, mst_rd_data_word_received0,
            mst_rd_data_word_received1, slv_nonposted_wr_data_word_received0, slv_nonposted_wr_data_word_received1,
            slv_posted_wr_data_word_received0, slv_posted_wr_data_word_received1, slv_rd_data_word_sent0,
            slv_rd_data_word_sent1, current, power, asic_temp, vcore, fan_rpm
        }
    }
}
