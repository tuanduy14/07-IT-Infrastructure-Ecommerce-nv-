# Thiết kế hạ tầng CNTT cho hệ thống thương mại điện tử (Đề 07)

Bài tập lớn học phần **Nhập môn Công nghệ nền tảng (RIPT1304)** – PTIT.
Hệ thống thương mại điện tử giả định gồm danh mục hàng, đặt hàng và đợt truy cập tăng đột biến. Toàn bộ dữ liệu là **dữ liệu giả**.


## 1. Kiến trúc tổng quan

```
Client ──► nginx (cổng 8080) ──► app1 ┐
           [mạng frontend]       app2 ┴──► PostgreSQL (db)
                                          [mạng backend, không mở cổng ra host]

Backup: PostgreSQL ──► backup-db.ps1 ──► file .dump + .sha256 ──► FTP Server ──(đề xuất)──► AWS S3
```

- **Tầng Web/Load Balancer:** nginx, chia tải round-robin tới 2 instance app.
- **Tầng ứng dụng:** API Node.js (Express) có 3 endpoint: `GET /api/products` (đọc), `POST /api/orders` (ghi), `GET /api/whoami` (cho biết instance nào đang phục vụ).
- **Tầng dữ liệu:** PostgreSQL, dữ liệu lưu ở volume `db_data`, không công bố cổng ra máy host.
- **Mô hình mạng 3 vùng (DMZ, Internal, Management):** dựng trong Packet Tracer, xem thư mục `network-design/`.

## 2. Cách dựng lại hệ thống

```powershell
cd app-source
docker compose -f docker-compose.yml -f docker-compose.ftp.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.ftp.yml ps
```

Kết quả đúng: 5 container `ecommerce_db`, `ecommerce_app1`, `ecommerce_app2`, `ecommerce_lb`, `ecommerce_ftp` ở trạng thái `Up`.

Nếu PowerShell chặn script: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`.


## 3. Cách chạy kiểm thử

**Cân bằng tải (KT1, dự phòng app):**
```powershell
1..6 | ForEach-Object { curl.exe -s http://localhost:8080/api/whoami }   
docker stop ecommerce_app1                                                  # app1/app2 xen kẽ
curl.exe -s http://localhost:8080/api/products                          
docker start ecommerce_app1                                                 # vẫn trả dữ liệu từ app2
```

**Đọc danh mục và ghi đơn hàng (KT1):**
```powershell
curl.exe -s http://localhost:8080/api/products
Invoke-RestMethod -Uri http://localhost:8080/api/orders -Method Post -ContentType "application/json" -Body '{"product_id":1,"quantity":2}'
```



**Sao lưu và phục hồi (KT3):**
```powershell
cd database-backup
.\backup-db.ps1                                   # tạo .dump + .sha256, ghi backup.log, đẩy lên FTP
.\restore-db.ps1                                  # restore bản mới nhất vào DB ecommerce_restore
.\restore-db.ps1 -BackupFile .\<tên_file>.dump    # restore một bản cụ thể
docker exec ecommerce_db psql -U postgres -d ecommerce_restore -c "SELECT * FROM orders;"
```
Kiểm tra lỗi FTP: `docker stop ecommerce_ftp`, chạy lại `backup-db.ps1`, log phải ghi `FAILED` nhưng bản local vẫn còn.


**Đo tải (3 mức, trước/sau cải tiến):** xem `testing-performance/`. ........ (SV4 bổ sung công cụ, lệnh và điều kiện đo)


## 4. Bảo mật

- Cổng PostgreSQL không mở ra máy host; DB chỉ nằm trong mạng `backend`, nginx không cùng mạng với DB.
- Mật khẩu `postgres` và tài khoản FTP `backup/backup123` là **dữ liệu giả cho demo**. Triển khai thực tế phải đổi và dùng biến môi trường hoặc secret.
- `.gitignore` chặn `*.dump`, `*.backup`, `*.log`, `.env`. Log dùng làm bằng chứng được sao chép sang `.txt` trong thư mục `evidence-*`.


sytax test:

cd app-source

docker compose -f docker-compose.yml -f docker-compose.ftp.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.ftp.yml ps

docker compose ps

1..6 | ForEach-Object { curl.exe -s http://localhost:8080/api/whoami }

curl.exe -s http://localhost:8080/api/products
 
docker stop ecommerce_app1

docker start ecommerce_app1



cd database-backup

Invoke-RestMethod -Uri http://localhost:8080/api/orders -Method Post -ContentType "application/json" -Body '{"product_id":1,"quantity":91}'

.\backup-db.ps1
docker exec ecommerce_ftp ls -la /home/backup

docker exec ecommerce_db psql -U postgres -d ecommerce_db -c "DELETE FROM orders WHERE quantity = 99;"

.\restore-db.ps1
 docker exec ecommerce_db psql -U postgres -d ecommerce_restore -c "SELECT * FROM orders;"

 docker exec ecommerce_db psql -U postgres -d ecommerce_db -c "SELECT * FROM orders;"