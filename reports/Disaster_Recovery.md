\# KẾ HOẠCH DISASTER RECOVERY – HỆ THỐNG THƯƠNG MẠI ĐIỆN TỬ



\## 1. Mục tiêu



Disaster Recovery (DR) là phương án khôi phục hệ thống và dữ liệu khi xảy ra sự cố nghiêm trọng như hỏng máy chủ, mất dữ liệu, lỗi cơ sở dữ liệu hoặc sự cố hệ thống mạng.



Mục tiêu là giảm thiểu thời gian gián đoạn hoạt động và đảm bảo dữ liệu thương mại điện tử có thể được khôi phục từ các bản sao lưu.



\## 2. Các tình huống sự cố



| Tình huống | Ảnh hưởng |

|---|---|

| PostgreSQL Database Server bị lỗi | Ứng dụng không truy cập được dữ liệu |

| File dữ liệu bị mất hoặc hỏng | Có nguy cơ mất thông tin sản phẩm và đơn hàng |

| Application Server gặp sự cố | Người dùng không truy cập được ứng dụng |

| Máy chủ lưu trữ backup bị hỏng | Không truy cập được bản sao lưu nội bộ |

| Sự cố mạng | Các máy chủ không thể giao tiếp |



\## 3. Mục tiêu khôi phục



\- RPO (Recovery Point Objective): Tối đa 24 giờ theo lịch sao lưu hằng ngày. Đây là mức mất dữ liệu tối đa dự kiến nếu chỉ dựa vào lịch backup hiện tại.

\- RTO (Recovery Time Objective): Mục tiêu khôi phục trong 2–4 giờ, tùy thuộc tình trạng máy chủ và quá trình khôi phục.



Các chỉ tiêu trên là mục tiêu đề xuất, chưa phải kết quả đo kiểm thực tế.



\## 4. Quy trình khôi phục hệ thống



\### Bước 1: Xác định sự cố

\- Kiểm tra tình trạng máy chủ và Docker Container.

\- Xác định cơ sở dữ liệu hoặc ứng dụng bị ảnh hưởng.

\- Ngăn các thao tác có thể làm ghi đè hoặc mất dữ liệu.



\### Bước 2: Chuẩn bị bản sao lưu

\- Tìm file backup PostgreSQL mới nhất trong thư mục `database-backup`.

\- Nếu bản sao lưu nội bộ không sử dụng được, lấy bản backup từ FTP Server.

\- Trong phương án mở rộng, có thể tải bản backup từ AWS S3.



\### Bước 3: Khôi phục PostgreSQL

\- Khởi động PostgreSQL Container.

\- Tạo cơ sở dữ liệu cần khôi phục.

\- Sử dụng `pg\_restore` để phục hồi dữ liệu từ file `.dump`.

\- Kiểm tra các bảng `products` và `orders`.



\### Bước 4: Khởi động Application Server

\- Khởi động các dịch vụ bằng Docker Compose.

\- Kiểm tra kết nối giữa Application Server và Database Server.

\- Kiểm tra API lấy danh sách sản phẩm và tạo đơn hàng.



\### Bước 5: Kiểm tra sau khôi phục

\- Xác nhận dữ liệu sản phẩm và đơn hàng tồn tại.

\- Kiểm tra ứng dụng hoạt động bình thường.

\- Kiểm tra khả năng truy cập FTP và bản sao lưu.

\- Ghi nhận nguyên nhân sự cố và kết quả khôi phục.



\## 5. Kết quả kiểm thử khôi phục đã thực hiện



Trong quá trình triển khai dự án, nhóm đã thực hiện:



1\. Tạo file backup PostgreSQL bằng `pg\_dump` ở định dạng Custom (`.dump`).

2\. Tạo database kiểm thử `ecommerce\_restore`.

3\. Khôi phục dữ liệu bằng `pg\_restore`.

4\. Kiểm tra bảng `orders` sau khôi phục.

5\. Xác nhận đơn hàng có `id = 1`, `product\_id = 1`, `quantity = 2` vẫn tồn tại.



Kết quả: Quá trình sao lưu và khôi phục dữ liệu PostgreSQL đã được kiểm tra thành công trên môi trường thử nghiệm.



\## 6. Biện pháp phòng ngừa



\- Duy trì sao lưu dữ liệu tự động hằng ngày.

\- Kiểm tra dung lượng và tính toàn vẹn của file backup.

\- Lưu thêm bản sao lưu trên FTP Server.

\- Đề xuất mở rộng lưu trữ lên AWS S3 để bảo vệ dữ liệu ngoài hệ thống nội bộ.

\- Kiểm tra định kỳ khả năng khôi phục dữ liệu.

\- Hạn chế quyền truy cập trái phép vào máy chủ và dữ liệu.



\## 7. Kết luận



Kế hoạch Disaster Recovery giúp hệ thống thương mại điện tử có khả năng khôi phục dữ liệu và dịch vụ khi xảy ra sự cố. Việc kết hợp PostgreSQL Backup, FTP Server, Docker và phương án lưu trữ AWS S3 giúp tăng khả năng bảo vệ dữ liệu và giảm thiểu rủi ro gián đoạn hoạt động.



\*\*Phạm vi thực hiện:\*\* Nhóm đã kiểm thử khôi phục PostgreSQL từ file backup trên môi trường Docker. Các tình huống khôi phục toàn bộ hệ thống và AWS S3 hiện là quy trình đề xuất, chưa được kiểm thử thực tế.

