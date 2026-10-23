# Quản Lý Sinh Viên – SQL Server + Docker + VS Code

Hướng dẫn cài đặt môi trường SQL Server chạy bằng Docker, kết nối từ VS Code và import dữ liệu từ file Excel do giáo viên cung cấp vào database `QuanLySinhVien`.

## Mục lục

1. [Yêu cầu](#1-yêu-cầu)
2. [Cài đặt Docker](#2-cài-đặt-docker)
3. [Cài VS Code và extension](#3-cài-vs-code-và-extension)
4. [Tạo SQL Server bằng Docker](#4-tạo-sql-server-bằng-docker)
5. [Kết nối SQL Server từ VS Code](#5-kết-nối-sql-server-từ-vs-code)
6. [Import dữ liệu từ file Excel](#6-import-dữ-liệu-từ-file-excel)
7. [Lỗi thường gặp](#7-lỗi-thường-gặp)

---

## 1. Yêu cầu

| Hệ điều hành | Ghi chú |
|---|---|
| Windows 10/11 | Cần bật Virtualization trong BIOS, dùng WSL2. Bản Home vẫn dùng được. |
| macOS | Chip Intel chạy bình thường. Chip Apple Silicon (M1/M2/M3) chạy SQL Server qua giả lập x86, xem lưu ý ở mục 2. |

---

## 2. Cài đặt Docker

### Windows

**Bước 1: Bật WSL2.** Mở PowerShell bằng quyền Administrator:

```powershell
wsl --install
```

Khởi động lại máy sau khi cài xong.

**Bước 2: Cài Docker Desktop.** Tải tại <https://www.docker.com/products/docker-desktop/>, khi được hỏi chọn backend **WSL2**.

**Bước 3: Kiểm tra:**

```powershell
docker --version
docker run hello-world
```

### macOS

Tải Docker Desktop tại cùng đường dẫn trên và cài như ứng dụng thông thường.

> **Apple Silicon (M1/M2/M3):** SQL Server chưa có bản ARM chính thức, nên cần bật giả lập x86. Vào Docker Desktop → **Settings → General** → bật **Use Rosetta for x86_64/amd64 emulation on Apple Silicon**. Khi chạy lệnh `docker run` thêm tham số `--platform linux/amd64`.

---

## 3. Cài VS Code và extension

1. Tải VS Code tại <https://code.visualstudio.com/>.
2. Mở tab **Extensions** (`Ctrl+Shift+X` hoặc `Cmd+Shift+X`) và cài:
   - **SQL Server (mssql)** của Microsoft.

Nếu dùng PostgreSQL hoặc MySQL thì có thể thay bằng extension **SQLTools** hoặc **Database Client**.

---

## 4. Tạo SQL Server bằng Docker

### Chạy container

**Windows (PowerShell), gõ trên một dòng:**

```powershell
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrong@Passw0rd" -p 1433:1433 --name sqlserver -v sqldata:/var/opt/mssql -d mcr.microsoft.com/mssql/server:2022-latest
```

**macOS Apple Silicon:**

```bash
docker run --platform linux/amd64 \
  -e "ACCEPT_EULA=Y" \
  -e "MSSQL_SA_PASSWORD=YourStrong@Passw0rd" \
  -p 1433:1433 --name sqlserver \
  -v sqldata:/var/opt/mssql \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

Giải thích tham số:

| Tham số | Ý nghĩa |
|---|---|
| `ACCEPT_EULA=Y` | Đồng ý điều khoản sử dụng của Microsoft |
| `MSSQL_SA_PASSWORD` | Mật khẩu tài khoản `sa` |
| `-p 1433:1433` | Mở cổng 1433 để kết nối từ máy thật |
| `--name sqlserver` | Tên container |
| `-v sqldata:/var/opt/mssql` | Lưu dữ liệu vào volume, xóa container không mất database |
| `-d` | Chạy nền |

> **Mật khẩu** cần tối thiểu 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt. Nếu không đủ mạnh, container sẽ tự tắt sau khi khởi động.
>
> **Không commit mật khẩu thật lên Git.** Thay `YourStrong@Passw0rd` bằng mật khẩu của bạn và không ghi nó vào file trong repo.

### Kiểm tra container

```bash
docker ps
```

Nếu thấy container `sqlserver` có trạng thái `Up` là đã chạy. Nếu không thấy, xem log:

```bash
docker logs sqlserver
```

### Các lệnh quản lý container

```bash
docker stop sqlserver      # Tắt
docker start sqlserver     # Bật lại (lần sau chỉ cần lệnh này)
docker rm -f sqlserver     # Xóa container (dữ liệu vẫn còn trong volume sqldata)
```

---

## 5. Kết nối SQL Server từ VS Code

1. Mở tab **SQL Server** ở thanh bên trái của VS Code.
2. Bấm **Add Connection** và nhập:

| Trường | Giá trị |
|---|---|
| Server | `localhost,1433` |
| Authentication | SQL Login |
| User name | `sa` |
| Password | mật khẩu đã đặt ở bước 4 |
| Trust server certificate | Có (Yes) |

3. Kết nối thành công, bạn sẽ thấy `localhost` cùng các mục **Databases**, **System Databases**.
4. Tạo database:

```sql
CREATE DATABASE QuanLySinhVien;
GO
USE QuanLySinhVien;
GO
```

5. Tạo file `.sql`, viết truy vấn và bấm nút **Run** (hoặc `Ctrl+Shift+E`) để chạy. Kết quả hiện ở tab **Query Results**.

---

## 6. Import dữ liệu từ file Excel

Giáo viên gửi file Excel (ví dụ `Import_QLSV_Table_Khoa.xls`). Cách làm được chọn: **import vào bảng tạm, kiểm tra, rồi chuyển sang bảng thật**. Cách này an toàn vì kiểm tra được dữ liệu trước khi đưa vào bảng chính.

### Các bước

1. **Lưu file Excel thành CSV UTF-8.** Mở file bằng Excel, chọn **Save As → CSV UTF-8 (Comma delimited)**. Phải chọn UTF-8, nếu không tiếng Việt sẽ bị lỗi font.

2. **Import vào bảng tạm.** Chuột phải vào database → **Import Data...** → chọn file CSV, đặt tên bảng mới là `SinhVien_tmp` (đừng trùng tên bảng thật).

3. **Xem thử dữ liệu:**

   ```sql
   SELECT * FROM SinhVien_tmp;
   ```

4. **Chuyển sang bảng thật**, bỏ qua các dòng bị trùng khóa chính:

   ```sql
   INSERT INTO SINHVIEN (MSSV, HoTen, MaKhoa)
   SELECT t.MSSV, t.HoTen, t.MaKhoa
   FROM SinhVien_tmp t
   WHERE NOT EXISTS (SELECT 1 FROM SINHVIEN s WHERE s.MSSV = t.MSSV);
   ```

5. **Xóa bảng tạm:**

   ```sql
   DROP TABLE SinhVien_tmp;
   ```

### Ví dụ với bảng KHOA

File `Import_QLSV_Table_Khoa.xls` có sheet `Khoa` gồm 3 cột `MaKhoa`, `TenKhoa`, `SL_CBGD`. Làm tương tự các bước trên với bảng tạm `Khoa_tmp`:

```sql
SELECT * FROM Khoa_tmp;

INSERT INTO KHOA (MaKhoa, TenKhoa, SL_CBGD)
SELECT t.MaKhoa, t.TenKhoa, t.SL_CBGD
FROM Khoa_tmp t
WHERE NOT EXISTS (SELECT 1 FROM KHOA k WHERE k.MaKhoa = t.MaKhoa);

DROP TABLE Khoa_tmp;
```

Với file ít dòng, có thể chèn trực tiếp:

```sql
INSERT INTO KHOA (MaKhoa, TenKhoa, SL_CBGD) VALUES
('KT', N'Kinh tế', 0),
('NN', N'Ngoại ngữ', 0);
```

### Lưu ý khi import

- **Thứ tự nhập:** nhập bảng cha trước (`KHOA`), rồi mới đến bảng con (`SINHVIEN`), nếu không sẽ lỗi khóa ngoại.
- **Kiểu dữ liệu bảng tạm:** wizard tự đoán kiểu, ví dụ cột ngày có thể thành chuỗi. Dùng `CAST` hoặc `CONVERT` ở bước 4 nếu kiểu không khớp.
- **Ngày tháng:** để dạng `yyyy-mm-dd` trong CSV để tránh nhầm ngày/tháng.
- **Tiếng Việt:** cột trong bảng phải là `NVARCHAR`, và khi chèn tay phải đặt chữ `N` trước chuỗi (`N'Kinh tế'`).

---

## 7. Lỗi thường gặp

| Lỗi | Nguyên nhân và cách xử lý |
|---|---|
| Container tự tắt sau khi chạy | Mật khẩu `sa` chưa đủ mạnh. Xóa container (`docker rm -f sqlserver`) và tạo lại với mật khẩu mạnh hơn. |
| Không kết nối được `localhost,1433` | Kiểm tra `docker ps` xem container có chạy không. Cổng 1433 có thể đang bị chương trình khác chiếm. |
| Lỗi chứng chỉ (certificate) | Bật **Trust server certificate** trong cấu hình kết nối. |
| Tiếng Việt hiện thành `?` | Cột chưa phải `NVARCHAR`, hoặc CSV chưa lưu dạng UTF-8. |
| Import báo lỗi trùng tên bảng | Đặt tên bảng tạm khác tên bảng thật (ví dụ `SinhVien_tmp`). |
| Insert báo trùng khóa chính | Dùng điều kiện `NOT EXISTS` như ở mục 6. |
| Docker Desktop ngốn RAM (Windows) | Giới hạn bằng file `%UserProfile%\.wslconfig`, ví dụ `[wsl2]` rồi `memory=4GB`. |

---

## Tài liệu tham khảo

- [SQL Server on Docker (Microsoft Learn)](https://learn.microsoft.com/sql/linux/quickstart-install-connect-docker)
- [Extension mssql cho VS Code](https://marketplace.visualstudio.com/items?itemName=ms-mssql.mssql)
- [Docker Desktop](https://docs.docker.com/desktop/)