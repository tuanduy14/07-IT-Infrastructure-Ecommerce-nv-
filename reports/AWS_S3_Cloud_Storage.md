\# THIẾT KẾ LƯU TRỮ ĐÁM MÂY AWS S3



\## 1. Mục tiêu



Sử dụng Amazon S3 (Simple Storage Service) làm giải pháp lưu trữ bản sao lưu cơ sở dữ liệu PostgreSQL trên nền tảng đám mây. Giải pháp giúp bảo vệ dữ liệu khi máy chủ nội bộ gặp sự cố, đồng thời hỗ trợ khôi phục hệ thống khi cần thiết.



\## 2. Kiến trúc lưu trữ



Hệ thống đề xuất luồng sao lưu như sau:



PostgreSQL Database → PowerShell Backup Script → Local Backup/FTP Server → AWS S3.



\- PostgreSQL: Cơ sở dữ liệu của hệ thống thương mại điện tử.

\- PowerShell Backup Script: Tự động tạo file sao lưu định dạng `.dump` mỗi ngày lúc 23:00.

\- Local Backup/FTP Server: Lưu trữ và cung cấp quyền truy cập các file sao lưu trong mạng nội bộ.

\- AWS S3: Lưu trữ bản sao lưu bên ngoài hệ thống nội bộ để tăng khả năng bảo vệ dữ liệu.



\## 3. Cấu hình lưu trữ AWS S3 đề xuất



\- Tạo một S3 Bucket riêng để chứa các file sao lưu PostgreSQL.

\- Bật Block Public Access để ngăn truy cập công khai.

\- Bật mã hóa dữ liệu khi lưu trữ bằng SSE-S3.

\- Bật Bucket Versioning để giữ các phiên bản của file.

\- Sử dụng IAM để phân quyền truy cập, chỉ cấp quyền cần thiết cho tài khoản thực hiện sao lưu và khôi phục.



\## 4. Chính sách lưu trữ



Đề xuất chính sách quản lý dữ liệu:



\- Bản sao lưu hằng ngày: Giữ trong 30 ngày.

\- Bản sao lưu hằng tháng: Giữ trong 12 tháng.

\- Xóa hoặc chuyển sang lớp lưu trữ tiết kiệm chi phí khi hết thời hạn theo chính sách.



Các thời hạn trên là thông số đề xuất cho dự án, có thể điều chỉnh theo dung lượng và nhu cầu thực tế.



\## 5. Quy trình khôi phục dữ liệu



Khi máy chủ nội bộ gặp sự cố và bản sao lưu cục bộ không thể sử dụng:



1\. Truy cập AWS S3 bằng tài khoản được cấp quyền.

2\. Tải file backup PostgreSQL mới nhất về máy chủ khôi phục.

3\. Sử dụng công cụ `pg\_restore` để khôi phục dữ liệu.

4\. Khởi động lại Application Server.

5\. Kiểm tra kết nối cơ sở dữ liệu và các chức năng API.



\## 6. Ưu điểm và hạn chế



\### Ưu điểm

\- Lưu trữ dữ liệu độc lập với máy chủ nội bộ.

\- Tăng khả năng bảo vệ dữ liệu khi xảy ra sự cố.

\- Có thể mở rộng dung lượng linh hoạt.

\- Hỗ trợ quản lý phiên bản và mã hóa dữ liệu.



\### Hạn chế

\- Cần kết nối Internet để tải lên và khôi phục dữ liệu.

\- Có thể phát sinh chi phí lưu trữ, truyền dữ liệu và yêu cầu truy cập.

\- Cần cấu hình quyền truy cập và bảo mật phù hợp.



\## 7. Kết luận



AWS S3 là giải pháp lưu trữ đám mây phù hợp để mở rộng hệ thống sao lưu PostgreSQL của dự án thương mại điện tử. Khi kết hợp với giải pháp backup nội bộ và FTP Server, hệ thống có thêm một lớp bảo vệ dữ liệu bên ngoài.



\*\*Phạm vi thực hiện:\*\* Đây là phương án thiết kế và đề xuất tích hợp AWS S3. Trong phạm vi triển khai hiện tại, hệ thống đã thực hiện sao lưu PostgreSQL và kiểm tra truyền file qua FTP; chưa triển khai kết nối hoặc tải dữ liệu lên AWS S3 thực tế.

