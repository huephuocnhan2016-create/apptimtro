/// MoMo's own result table, in the wording the sample app shows on its
/// "Result Codes" screen. The portal's message wins whenever it sends one;
/// this list is what the student can look up while waiting.
const Map<String, String> kMomoResultCodes = {
  '0': 'Thành công.',
  '10': 'Hệ thống đang được bảo trì.',
  '11': 'Truy cập bị từ chối.',
  '12': 'Phiên bản API không được hỗ trợ.',
  '13': 'Xác thực doanh nghiệp thất bại.',
  '20': 'Yêu cầu sai định dạng.',
  '21': 'Số tiền giao dịch không hợp lệ.',
  '22': 'Số tiền giao dịch không hợp lệ.',
  '40': 'RequestId bị trùng.',
  '41': 'OrderId bị trùng.',
  '42': 'OrderId không hợp lệ hoặc không tìm thấy.',
  '98': 'QR Code tạo không thành công.',
  '99': 'Lỗi không xác định.',
  '1000': 'Giao dịch đã khởi tạo, chờ xác nhận.',
  '1001': 'Giao dịch thất bại do không đủ tiền.',
  '1002': 'Giao dịch bị từ chối bởi nhà phát hành.',
  '1003': 'Giao dịch đã bị hủy.',
  '1004': 'Giao dịch thất bại do vượt quá hạn mức.',
  '1005': 'Giao dịch thất bại do URL/QR hết hạn.',
  '1006': 'Người dùng từ chối xác nhận.',
  '7000': 'Giao dịch đang được xử lý.',
  '9000': 'Giao dịch được xác nhận thành công.',
};
