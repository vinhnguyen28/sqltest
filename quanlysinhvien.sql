-- ================================================================================================
-- FILE : quanlysinhvien.sql  |  DBMS: SQL Server (T-SQL)  |  Database: QuanLySinhVien
-- BẢN NÀY: code gốc GIỮ NGUYÊN 100% - chỉ CHÈN thêm các dòng comment bắt đầu bằng '--'
-- ================================================================================================
-- ================================================================================================
-- SECTION: 0. TỔNG QUAN FILE - MÔ HÌNH DỮ LIỆU - CÁCH ĐỌC CHÚ THÍCH
-- ================================================================================================
-- NOTE: Đây là bài tập T-SQL "Quản lý sinh viên": tạo database, 6 bảng, nhập dữ liệu mẫu, rồi làm các câu
--       truy vấn SELECT / GROUP BY / sub-query / phép chia / ALTER / UPDATE / DELETE đánh số từ câu 1 đến
--       câu 95.
--   Sơ đồ quan hệ giữa các bảng (1──N = một-nhiều):
--       KHOA     1──N GIAOVIEN   (GIAOVIEN.MaKhoa  → KHOA.MaKhoa)
--       KHOA     1──N SINHVIEN   (SINHVIEN.MaKhoa  → KHOA.MaKhoa)
--       GIAOVIEN 1──N GIANGDAY   (GIANGDAY.MaGV    → GIAOVIEN.MaGV)
--       MONHOC   1──N GIANGDAY   (GIANGDAY.MaMH    → MONHOC.MaMH)
--       SINHVIEN 1──N KETQUA N──1 GIANGDAY   (KETQUA = bảng nối SV ↔ khóa học, khóa chính kép)
--   => GIANGDAY là "khóa học" (1 GV dạy 1 môn trong 1 học kỳ/niên khóa); KETQUA là điểm của SV ở khóa đó.
--   => Muốn biết SV học MÔN nào phải đi: KETQUA → GIANGDAY → MONHOC.
--
--   CÁCH ĐỌC CÁC THẺ (dành cho extension Todo Tree - cấu hình ở phần trả lời):
--     • SECTION : tiêu đề từng PHẦN lớn          → dùng như "mục lục" trong cây Todo Tree
--     • CAU     : tiêu đề từng CÂU truy vấn / từng bảng
--     • NOTE    : giải thích CÁCH HOẠT ĐỘNG
--     • CACH    : các cách viết khác nhau cho cùng một đề
--     • TODO    : việc còn thiếu / nên làm thêm
--     • FIXME   : lỗi làm câu lệnh BÁO LỖI khi chạy (cần sửa)
--     • BUG     : chạy được nhưng kết quả / logic sai, hoặc dữ liệu mâu thuẫn
--
--   MỤC LỤC: 1 Tạo DB → 2 Tạo bảng → 3 Dữ liệu mẫu → 4 Truy vấn cơ bản (câu 1-28) → 5 Hàm tổng hợp (29-49)
--            → 6 Sub-query MAX/MIN (51-57) → 7 LEFT JOIN/IIF/ISNULL (66-73) → 8 Phép chia (82-86)
--            → 9 ALTER/UPDATE (90-92) → 10 DELETE (93-95) → 11 Nhập CSV qua bảng phụ
--
-- NOTE: Dấu GO không phải lệnh T-SQL mà là dấu tách "batch" của SSMS/sqlcmd: mỗi batch được biên dịch và
--       chạy riêng. Lệnh dùng cột vừa tạo bằng ALTER ... ADD phải nằm ở batch SAU (sau một GO).
-- NOTE: Số câu trong file bị nhảy: không có câu 46, 50, 58-65, 74-81, 87-89 (có thể đề không giao hoặc chưa
--       làm).
-- NOTE: Kết quả mẫu ghi trong chú thích được tính tay từ dữ liệu INSERT trong file này.
USE master;
GO

-- ================================================================================================
-- SECTION: 1. TẠO DATABASE (chạy lại script nhiều lần vẫn an toàn)
-- ================================================================================================
-- NOTE: USE master: phải đứng ở database "master" vì không thể DROP một database đang được dùng.
-- NOTE: IF EXISTS(SELECT ... FROM sys.databases WHERE name = ...) DROP DATABASE: nếu QuanLySinhVien đã có
--       thì XÓA SẠCH rồi tạo lại từ đầu (reset toàn bộ dữ liệu). Lần chạy đầu chưa có DB thì bỏ qua lệnh
--       DROP.
-- NOTE: CREATE DATABASE bắt buộc nằm trong batch riêng (vì vậy có GO ngay sau); USE QuanLySinhVien chuyển
--       sang DB mới tạo.
-- TODO: Nếu DROP báo "database is in use" (còn kết nối khác đang mở): thêm TRƯỚC lệnh DROP: ALTER DATABASE
--       QuanLySinhVien SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'QuanLySinhVien')
    DROP DATABASE QuanLySinhVien;
GO
CREATE DATABASE QuanLySinhVien;

GO
USE QuanLySinhVien;
GO

-- ================================================================================================
-- SECTION: 2. TẠO BẢNG (DDL) - bảng cha tạo trước, bảng con tạo sau (vì có khóa ngoại)
-- ================================================================================================
-- CAU: Bảng KHOA - danh mục khoa (bảng cha của GIAOVIEN và SINHVIEN)
-- NOTE: MaKhoa VARCHAR(10) PRIMARY KEY: khóa chính - duy nhất, không NULL (vd CNTT, TOAN, SINH).
-- NOTE: TenKhoa NVARCHAR(100) NOT NULL: chữ N đầu kiểu = Unicode để lưu tiếng Việt có dấu; NOT NULL = bắt
--       buộc nhập.
-- NOTE: SL_CBGD (số cán bộ giảng dạy): DEFAULT 0 (không nhập thì = 0) + CHECK BETWEEN 0 AND 4 (chỉ nhận
--       0..4).
CREATE TABLE KHOA (
    MaKhoa VARCHAR(10) PRIMARY KEY,
    TenKhoa NVARCHAR(100) NOT NULL,
    SL_CBGD INT DEFAULT 0 CHECK (SL_CBGD BETWEEN 0 AND 4)
);

-- CAU: Bảng MONHOC - danh mục môn học (bảng cha của GIANGDAY)
-- NOTE: MaMH là khóa chính (vd CSDL, CTDL). SoTC_ToiThieu có CHECK >= 2: môn nào cũng tối thiểu 2 tín chỉ.
-- NOTE: CHECK chỉ chặn khi điều kiện FALSE; nếu SoTC_ToiThieu là NULL thì điều kiện = UNKNOWN và vẫn được
--       cho qua.
CREATE TABLE MONHOC (
    MaMH VARCHAR(10) PRIMARY KEY,
    TenMH NVARCHAR(100) NOT NULL,
    SoTC_ToiThieu INT CHECK (SoTC_ToiThieu >= 2)
);

-- CAU: Bảng GIAOVIEN - có khóa ngoại tới KHOA
-- NOTE: MaGV VARCHAR(4) + CHECK LIKE '[A-Z][0-9][0-9][FM]': đúng 4 ký tự = 1 chữ cái + 2 chữ số + F hoặc M
--       (giới tính). Hợp lệ: 'C01F', 'T02M'. [A-Z] = 1 ký tự trong dải A..Z; [FM] = F hoặc M.
-- NOTE: CONSTRAINT FK_GiaoVien_Khoa FOREIGN KEY ...: MaKhoa phải tồn tại trong KHOA (hoặc NULL). Đặt tên
--       constraint giúp dễ DROP/ALTER về sau.
CREATE TABLE GIAOVIEN (
    MaGV VARCHAR(4) PRIMARY KEY 
        CHECK (MaGV LIKE '[A-Z][0-9][0-9][FM]'),
    TenGV NVARCHAR(100) NOT NULL,
    MaKhoa VARCHAR(10),
    CONSTRAINT FK_GiaoVien_Khoa FOREIGN KEY (MaKhoa) REFERENCES KHOA(MaKhoa)
);

-- CAU: Bảng SINHVIEN - nhiều ràng buộc nhất trong file
-- NOTE: MSSV VARCHAR(6) + CHECK LIKE '[A-Z][0-9][0-9][0-9][0-9][FM]': 1 chữ + 4 số + F/M (vd 'C0001F').
-- NOTE: PhaiNu TINYINT CHECK IN (0,1): 1 = nữ, 0 = nam.
-- NOTE: DienThoai: CHECK (LEN = 8 OR LEN = 10) AND NOT LIKE '%[^0-9]%' - độ dài 8 hoặc 10 và KHÔNG chứa ký
--       tự nào ngoài 0-9 ([^0-9] nghĩa là 'ký tự không phải chữ số').
-- NOTE: SoCMND VARCHAR(20) UNIQUE: không được trùng nhau nhưng cho phép NULL (SQL Server chỉ cho đúng 1
--       NULL với UNIQUE).
-- NOTE: CONSTRAINT FK_SinhVien_Khoa: MaKhoa tham chiếu KHOA(MaKhoa).
-- NOTE: CHECK DATEDIFF(YEAR, NgaySinh, NgayNhapHoc) >= 18: nhập học phải đủ 18 tuổi. DATEDIFF(YEAR) chỉ trừ
--       NĂM, không xét tháng/ngày (31/12/2000 → 01/01/2018 vẫn tính là 18).
-- NOTE: Vào Đoàn: NULL hoặc >= 16 tuổi. Vào Đảng: NULL hoặc NgayVaoDang >= NgayVaoDoan (không được vào Đảng
--       trước Đoàn).
-- NOTE: Quy tắc chung: CHECK chỉ chặn khi kết quả là FALSE. Kết quả UNKNOWN (do cột NULL) vẫn cho qua, nên
--       cột bỏ trống không bị kiểm tra.
-- NOTE: Ràng buộc cho LyDoNgungHoc không nằm ở đây mà được thêm bằng ALTER TABLE ngay sau khi tạo xong các
--       bảng.
CREATE TABLE SINHVIEN (
    MSSV VARCHAR(6) PRIMARY KEY 
        CHECK (MSSV LIKE '[A-Z][0-9][0-9][0-9][0-9][FM]'),
    Ten NVARCHAR(100) NOT NULL,
    PhaiNu TINYINT CHECK (PhaiNu IN (0, 1)),
    DiaChi NVARCHAR(255) NOT NULL,
    DienThoai VARCHAR(15) 
    CHECK ((LEN(DienThoai) = 8 OR LEN(DienThoai) = 10) AND DienThoai NOT LIKE '%[^0-9]%'),
    MaKhoa VARCHAR(10),
    SoCMND VARCHAR(20) UNIQUE,
    NgaySinh DATE,
    NgayNhapHoc DATE NOT NULL,
    NgayVaoDoan DATE,
    NgayVaoDang DATE,
    NgayRaTruong DATE,
    LyDoNgungHoc NVARCHAR(100),
    CONSTRAINT FK_SinhVien_Khoa FOREIGN KEY (MaKhoa) REFERENCES KHOA(MaKhoa),
    CHECK (DATEDIFF(YEAR, NgaySinh, NgayNhapHoc) >= 18), 
    CHECK (NgayVaoDoan IS NULL OR DATEDIFF(YEAR, NgaySinh, NgayVaoDoan) >= 16),
    CHECK (NgayVaoDang IS NULL OR NgayVaoDang >= NgayVaoDoan)
);

-- CAU: Bảng GIANGDAY - "khóa học" = một lần mở lớp: 1 giáo viên dạy 1 môn trong 1 học kỳ / niên khóa
-- NOTE: MaKhoaHoc VARCHAR(4) PRIMARY KEY + CHECK LIKE 'K[0-9][0-9][0-9]': dạng K001..K999.
-- NOTE: HocKy chỉ nhận 1, 2, 3. TongSoTC từ 2 đến 6. SoTCLT / SoTCTH (tín chỉ lý thuyết / thực hành) >= 0,
--       mặc định 0.
-- NOTE: CHECK (TongSoTC = SoTCLT + SoTCTH): tổng tín chỉ phải đúng bằng lý thuyết + thực hành.
-- NOTE: SoTietLT AS (SoTCLT * 15) và SoTietTH AS (SoTCTH * 30) là CỘT TÍNH TOÁN (computed column): không
--       lưu dữ liệu, tự tính mỗi khi SELECT; vì vậy các lệnh INSERT bên dưới KHÔNG đưa 2 cột này vào.
-- NOTE: Hai khóa ngoại: MaGV → GIAOVIEN, MaMH → MONHOC.
-- TODO: Chưa có CHECK về thứ tự ngày (vd NgayBatDauLyThuyet <= NgayKetThuc) nên dữ liệu ngày sai vẫn vào
--       được (xem khóa K003 ở phần INSERT).
CREATE TABLE GIANGDAY (
    MaKhoaHoc VARCHAR(4) PRIMARY KEY 
    CHECK (MaKhoaHoc LIKE 'K[0-9][0-9][0-9]'), 
    MaGV VARCHAR(4),
    MaMH VARCHAR(10),
    HocKy INT CHECK (HocKy IN (1, 2, 3)),
    NienKhoa VARCHAR(20),
    NgayBatDauLyThuyet DATE,
    NgayBatDauThucHanh DATE,
    NgayKetThuc DATE,
    TongSoTC INT CHECK (TongSoTC BETWEEN 2 AND 6),
    SoTCLT INT DEFAULT 0 CHECK (SoTCLT >= 0),
    SoTCTH INT DEFAULT 0 CHECK (SoTCTH >= 0),
    SoTietLT AS (SoTCLT * 15),
    SoTietTH AS (SoTCTH * 30),
    CONSTRAINT FK_GiangDay_GiaoVien FOREIGN KEY (MaGV) REFERENCES GIAOVIEN(MaGV),
    CONSTRAINT FK_GiangDay_MonHoc FOREIGN KEY (MaMH) REFERENCES MONHOC(MaMH),
    CHECK (TongSoTC = SoTCLT + SoTCTH)
);

-- CAU: Bảng KETQUA - bảng nối nhiều-nhiều giữa SINHVIEN và GIANGDAY (điểm của từng SV ở từng khóa)
-- NOTE: PRIMARY KEY (MSSV, MaKhoaHoc) = khóa chính KÉP: mỗi SV chỉ có đúng 1 dòng kết quả cho mỗi khóa học.
-- NOTE: Ba điểm thành phần DiemKTGiuaKy / DiemThiLan1 / DiemThiLan2 (0..10, DEFAULT 0); DiemKhoaHoc là điểm
--       tổng kết do người nhập nhập tay (không phải computed column).
-- NOTE: Quan sát từ dữ liệu mẫu (không có trong code): DiemKhoaHoc = 40% giữa kỳ + 60% điểm thi cao nhất
--       của (lần 1, lần 2). Vd 8.5*0.4 + 5*0.6 = 6.4.
-- NOTE: DEFAULT 0 của điểm chỉ có tác dụng khi KHÔNG đưa cột vào INSERT. Các INSERT bên dưới truyền NULL
--       tường minh cho DiemThiLan2 nên giá trị vẫn là NULL (= không thi lần 2).
-- NOTE: Hai khóa ngoại: MSSV → SINHVIEN, MaKhoaHoc → GIANGDAY.
CREATE TABLE KETQUA (
    MSSV VARCHAR(6),
    MaKhoaHoc VARCHAR(4),
    DiemKTGiuaKy FLOAT DEFAULT 0 CHECK (DiemKTGiuaKy BETWEEN 0 AND 10),
    DiemThiLan1 FLOAT DEFAULT 0 CHECK (DiemThiLan1 BETWEEN 0 AND 10),
    DiemThiLan2 FLOAT DEFAULT 0 CHECK (DiemThiLan2 BETWEEN 0 AND 10),
    DiemKhoaHoc FLOAT, 
    PRIMARY KEY (MSSV, MaKhoaHoc),
    CONSTRAINT FK_KetQua_SinhVien FOREIGN KEY (MSSV) REFERENCES SINHVIEN(MSSV),
    CONSTRAINT FK_KetQua_GiangDay FOREIGN KEY (MaKhoaHoc) REFERENCES GIANGDAY(MaKhoaHoc)
);

GO

-- CAU: ALTER TABLE ... ADD CONSTRAINT CHK_LyDoNgungHoc - thêm ràng buộc sau khi bảng đã tạo
-- NOTE: LyDoNgungHoc chỉ nhận 1 trong 6 giá trị cố định hoặc NULL (NULL = SV đang học bình thường).
-- NOTE: Chuỗi viết dạng N'...' (Unicode) và phải gõ đúng y như đã khai báo (chữ thường, đủ dấu), vd N'xin
--       thôi học'.
ALTER TABLE SINHVIEN
ADD CONSTRAINT CHK_LyDoNgungHoc CHECK (
    LyDoNgungHoc IN (
        N'hoàn tất chương trình', 
        N'nghỉ học giữa khóa học', 
        N'buộc thôi học', 
        N'xin thôi học', 
        N'xin tạm ngừng', 
        N'khác'
    ) OR LyDoNgungHoc IS NULL
);
GO

-- ================================================================================================
-- SECTION: 3. NHẬP DỮ LIỆU MẪU (thứ tự INSERT phải theo khóa ngoại)
-- ================================================================================================
-- NOTE: Thứ tự bắt buộc: KHOA → SINHVIEN / GIAOVIEN / MONHOC → GIANGDAY → KETQUA. Chèn bảng con trước bảng
--       cha sẽ vi phạm FOREIGN KEY.
-- CAU: KHOA - 3 khoa: CNTT, TOAN, SINH
-- BUG: SL_CBGD không khớp bảng GIAOVIEN: CNTT = 3 (đúng, có 3 GV) nhưng TOAN = 1 trong khi có 2 GV (T02M,
--      T05F). SINH = 0 là đúng.
-- NOTE: Khoa SINH không có SV lẫn GV → dùng để kiểm thử LEFT JOIN (câu 69, 70) và DELETE khoa không có SV
--       (câu 95).
INSERT INTO KHOA (MaKhoa, TenKhoa, SL_CBGD) VALUES 
('CNTT', N'Công nghệ thông tin', 3),
('TOAN', N'Toán', 1),
('SINH', N'Sinh học', 0);
GO

-- CAU: SINHVIEN - 5 sinh viên (5 lệnh INSERT, mỗi lệnh 1 dòng)
-- NOTE: INSERT ... VALUES không liệt kê tên cột → 13 giá trị phải đúng THỨ TỰ cột lúc CREATE TABLE: MSSV,
--       Ten, PhaiNu, DiaChi, DienThoai, MaKhoa, SoCMND, NgaySinh, NgayNhapHoc, NgayVaoDoan, NgayVaoDang,
--       NgayRaTruong, LyDoNgungHoc.
-- TODO: Nên ghi rõ danh sách cột: INSERT INTO SINHVIEN (MSSV, Ten, ...) VALUES (...) để không vỡ khi
--       thêm/xóa cột sau này (phần 9 có ALTER thêm nhiều cột).
-- NOTE: Mỗi dòng đều phải qua các CHECK ở trên (đủ 18 tuổi khi nhập học, vào Đoàn >= 16 tuổi, ...).
-- NOTE: Điểm đáng chú ý: C0001F đã nghỉ (có NgayRaTruong + LyDoNgungHoc); T0003M và T0005M có NgayVaoDoan;
--       C0004F KHÔNG có điểm nào trong KETQUA → SV "chưa thi" dùng cho các câu 36, 66, 67, 73.
INSERT INTO SINHVIEN VALUES ('C0001F', N'Bùi Thúy An', 1, N'223 Trần Hưng Đạo, HCM', '38132202', 'CNTT', '135792468', '1992-08-14', '2010-10-01', NULL, NULL, '2012-11-15', N'xin thôi học');
INSERT INTO SINHVIEN VALUES ('C0002M', N'Nguyễn Thanh Tùng', 0, N'140 Công Quỳnh, Sóc Trăng', '38125678', 'CNTT', '987654321', '1992-11-23', '2010-11-23', NULL, NULL, NULL, NULL);
INSERT INTO SINHVIEN VALUES ('T0003M', N'Nguyễn Thành Long', 0, N'112/4 Công Quỳnh, HCM', '0918345623', 'TOAN', '123456789', '1991-08-17', '2010-10-01', '2007-08-17', '2012-05-01', NULL, NULL);
INSERT INTO SINHVIEN VALUES ('C0004F', N'Hoàng Thị Hoa', 1, N'90 Nguyễn Văn Cừ, HCM', '38320123', 'CNTT', '246813579', '1991-09-02', '2010-10-17', NULL, NULL, NULL, NULL);
INSERT INTO SINHVIEN VALUES ('T0005M', N'Trần Hồng Sơn', 0, N'54 Cao Thắng, Hà Nội', '38345987', 'TOAN', '864297531', '1993-04-24', '2011-10-15', '2010-09-02', NULL, NULL, NULL);
GO

-- NOTE: Dòng USE này thừa (DB đã được chọn từ đầu file) nhưng vô hại - chỉ để chắc chắn đang đứng đúng
--       database.
USE QuanLySinhVien;
GO

-- CAU: GIAOVIEN - 5 giáo viên (CNTT: C01F, C03M, C04M; TOAN: T02M, T05F)
-- NOTE: Lệnh này có liệt kê cột (MaGV, TenGV, MaKhoa) - cách viết an toàn hơn so với INSERT SINHVIEN ở
--       trên.
INSERT INTO GIAOVIEN (MaGV, TenGV, MaKhoa) VALUES 
('C01F', N'Phạm Thị Thảo', 'CNTT'),
('T02M', N'Lâm Hoàng Vũ', 'TOAN'),
('C03M', N'Trần Văn Tiến', 'CNTT'),
('C04M', N'Hoàng Vương', 'CNTT'),
('T05F', N'Thanh Trà', 'TOAN');
GO

-- CAU: MONHOC - 6 môn: CSDL, CTDL, KTLT, CWIN, TRR, LTDT
-- NOTE: SoTC_ToiThieu của mọi môn đều >= 2 (thỏa CHECK).
INSERT INTO MONHOC (MaMH, TenMH, SoTC_ToiThieu) VALUES 
('CSDL', N'Cơ sở dữ liệu', 2),
('CTDL', N'Cấu trúc dữ liệu', 3),
('KTLT', N'Kỹ thuật lập trình', 3),
('CWIN', N'Lập trình C trên Windows', 3),
('TRR', N'Toán rời rạc', 2),
('LTDT', N'Lý thuyết đồ thị', 2);
GO

-- CAU: GIANGDAY - 9 khóa học K001..K009
-- NOTE: Không đưa SoTietLT / SoTietTH vào vì là computed column. TongSoTC phải bằng SoTCLT + SoTCTH (vd 4 =
--       3 + 1, 2 = 2 + 0).
-- NOTE: C04M (Hoàng Vương) dạy 6 khóa (K002, K004, K006, K007, K008, K009) → là GV dạy nhiều khóa nhất (câu
--       54). C01F, C03M, T02M mỗi người 1 khóa; T05F không dạy khóa nào (câu 41, câu 70).
-- BUG: K003: NgayBatDauThucHanh = 2012-03-14 nhưng NgayBatDauLyThuyet = 2012-09-11 (thực hành bắt đầu TRƯỚC
--      lý thuyết 6 tháng) - nhiều khả năng gõ nhầm tháng; không có CHECK nên SQL Server không báo lỗi.
-- NOTE: K006-K009 có cùng ngày và tín chỉ với K001 → có vẻ là dữ liệu sao chép để kiểm thử các câu theo
--       niên khóa 2011-2012.
INSERT INTO GIANGDAY (MaKhoaHoc, MaGV, MaMH, HocKy, NienKhoa, NgayBatDauLyThuyet, NgayBatDauThucHanh, NgayKetThuc, TongSoTC, SoTCLT, SoTCTH) VALUES 
('K001', 'C01F', 'CSDL', 1, '2011-2012', '2011-09-15', '2011-10-01', '2012-01-02', 4, 3, 1),
('K002', 'C04M', 'KTLT', 2, '2011-2012', '2012-02-17', '2012-03-01', '2012-05-18', 4, 2, 2),
('K003', 'C03M', 'CTDL', 1, '2012-2013', '2012-09-11', '2012-03-14', '2013-01-03', 4, 3, 1),
('K004', 'C04M', 'CWIN', 1, '2012-2013', '2012-09-13', '2012-10-13', '2013-01-14', 4, 2, 2),
('K005', 'T02M', 'TRR',  1, '2012-2013', '2012-09-14', '2012-10-02', '2013-01-18', 2, 2, 0),
('K006', 'C04M', 'CSDL', 1, '2011-2012', '2011-09-15', '2011-10-01', '2012-01-02', 4, 3, 1),
('K007', 'C04M', 'CTDL', 1, '2011-2012', '2011-09-15', '2011-10-01', '2012-01-02', 4, 3, 1),
('K008', 'C04M', 'TRR',  1, '2011-2012', '2011-09-15', '2011-10-01', '2012-01-02', 4, 3, 1),
('K009', 'C04M', 'LTDT', 1, '2011-2012', '2011-09-15', '2011-10-01', '2012-01-02', 4, 3, 1);
GO

-- CAU: KETQUA - 10 dòng kết quả học tập
-- NOTE: NULL ở DiemThiLan2 = không thi lần 2. Chỉ 3 dòng có thi lại: (T0003M, K003), (C0002M, K001),
--       (T0003M, K002).
-- NOTE: Số khóa mỗi SV: C0001F 4, T0003M 3, T0005M 2, C0002M 1, C0004F 0.
-- NOTE: Từ đây trở xuống là phần TRUY VẤN; mỗi câu đều có chú thích cách hoạt động và kết quả mẫu.
INSERT INTO KETQUA (MSSV, MaKhoaHoc, DiemKTGiuaKy, DiemThiLan1, DiemThiLan2, DiemKhoaHoc) VALUES 
('C0001F', 'K001', 8.5, 5,  NULL, 6.4),
('C0001F', 'K003', 8.0, 9,  NULL, 8.6),
('T0003M', 'K004', 9.0, 7,  NULL, 7.8),
('C0001F', 'K002', 9.0, 7,  NULL, 7.8),
('T0003M', 'K003', 6.0, 2,  2.5,  3.9),
('T0005M', 'K003', 9.0, 7,  NULL, 7.8),
('C0002M', 'K001', 7.0, 2,  5,    5.8),
('T0003M', 'K002', 6.5, 2,  3,    4.4),
('T0005M', 'K005', 7.0, 10, NULL, 8.8),
('C0001F', 'K004', 8.0, 9,  NULL, 8.6);
GO

-- ================================================================================================
-- SECTION: 4. TRUY VẤN SELECT CƠ BẢN (câu 1 → 28)
-- ================================================================================================
-- CAU: 1 - Tên, địa chỉ, điện thoại của mọi sinh viên
-- NOTE: Cú pháp gốc: SELECT <danh sách cột> FROM <bảng>. Không có WHERE nên trả về TẤT CẢ dòng (5 SV).
-- 1. Cho biết tên, địa chỉ, điện thọai của tất cả các sinh viên.
SELECT Ten, DiaChi, DienThoai 
FROM SINHVIEN;
GO

-- CAU: 2 - Tên môn học + số tín chỉ tối thiểu
-- NOTE: Cùng dạng câu 1 trên bảng MONHOC → 6 dòng.
-- 2. Cho biết tên các môn học và số tín chỉ tối thiểu của từng môn học.
SELECT TenMH, SoTC_ToiThieu 
FROM MONHOC;
GO

-- CAU: 3 - Kết quả học tập của SV mã 'T0003M'
-- NOTE: WHERE MSSV = 'T0003M' lọc dòng theo mã SV; SELECT * lấy mọi cột của KETQUA → 3 dòng (K002, K003,
--       K004).
-- 3. Cho biết kết quả học tập của sinh viên có Mã số “T0003M”.
SELECT * 
FROM KETQUA 
WHERE MSSV = 'T0003M';
GO

-- CAU: 4 - Giáo viên có ký tự thứ 3 của họ tên là 'A'
-- NOTE: LIKE dùng ký tự đại diện: '_' = đúng 1 ký tự bất kỳ, '%' = chuỗi bất kỳ (kể cả rỗng). '__A%' = 2 ký
--       tự bất kỳ + 'A' + phần còn lại.
-- NOTE: Vị trí đếm trên cả chuỗi TenGV, tính cả dấu cách. Vd 'Thanh Trà' = T-h-a… ký tự thứ 3 là 'a' →
--       khớp. Nếu collation phân biệt dấu thì Phạm/Lâm/Trần/Hoàng không khớp → kết quả mẫu: Thanh Trà.
-- NOTE: Nhánh OR LIKE '__a%' thực ra thừa nếu collation không phân biệt hoa/thường (mặc định của SQL
--       Server).
-- 4. Cho biết tên các giáo viên có ký tự thứ 3 của họ và tên là “A”.
SELECT TenGV 
FROM GIAOVIEN 
WHERE TenGV LIKE '__A%' OR TenGV LIKE '__a%';
GO

-- CAU: 5 - Môn học có chứa chữ 'dữ'
-- NOTE: '%dữ%' = chứa 'dữ' ở bất kỳ vị trí nào. Phải viết N'...' (Unicode) - nếu thiếu N, ký tự có dấu có
--       thể bị đổi thành '?' làm mất kết quả.
-- NOTE: Kết quả mẫu: Cơ sở dữ liệu, Cấu trúc dữ liệu.
-- 5. Cho biết tên những môn học có chứa chữ “dữ”.
SELECT TenMH 
FROM MONHOC 
WHERE TenMH LIKE N'%dữ%';
GO


-- CAU: 6 - Giáo viên có tên bắt đầu bằng 'P' hoặc 'L'
-- NOTE: LIKE 'P%' = bắt đầu bằng P; OR nối hai điều kiện. Có thể viết gọn: LIKE '[PL]%'. → Phạm Thị Thảo,
--       Lâm Hoàng Vũ.
-- 6. Cho biết tên các giáo viên có ký tự đầu tiên của họ và tên là các ký tự “P” hoặc “L”.
SELECT TenGV 
FROM GIAOVIEN 
WHERE TenGV LIKE 'P%' OR TenGV LIKE 'L%';
GO

-- CAU: 7 - Sinh viên ở đường 'Công Quỳnh'
-- NOTE: LIKE N'%Công Quỳnh%' tìm chuỗi nằm GIỮA địa chỉ. Đề viết 'Cống Quỳnh' nhưng dữ liệu là 'Công Quỳnh'
--       nên code tìm theo dữ liệu → Nguyễn Thanh Tùng, Nguyễn Thành Long.
-- 7. Cho biết tên, địa chỉ của những sinh viên có địa chỉ trên đường “Cống Quỳnh”.
SELECT Ten, DiaChi 
FROM SINHVIEN 
WHERE DiaChi LIKE N'%Công Quỳnh%';
GO

-- CAU: 8 - Môn học có mã dạng 'C_D...' (ký tự 1 là C, ký tự 3 là D)
-- NOTE: JOIN MONHOC với GIANGDAY qua MaMH để lấy thêm MaKhoaHoc và TongSoTC.
-- NOTE: 'C_D%' = C + 1 ký tự bất kỳ + D → khớp CSDL và CTDL. Mỗi môn có thể ra nhiều khóa (CSDL: K001,
--       K006; CTDL: K003, K007).
-- 8. Cho biết mã môn học, tên môn học, mã khóa học và tổng số tín chỉ (TongSoTC) của những môn học có cấu trúc của mã môn học như sau: ký tự thứ 1 là “C”, ký tự thứ 3 là “D”.
SELECT m.MaMH, m.TenMH, g.MaKhoaHoc, g.TongSoTC 
FROM MONHOC m
JOIN GIANGDAY g ON m.MaMH = g.MaMH
WHERE m.MaMH LIKE 'C_D%';
GO

-- CAU: 9 - Tên môn học được dạy trong niên khóa 2011-2012
-- NOTE: JOIN rồi lọc NienKhoa. DISTINCT loại dòng trùng vì một môn có thể mở nhiều khóa (CSDL có cả K001 và
--       K006) → 5 môn: CSDL, KTLT, CTDL, TRR, LTDT.
-- 9. Cho biết tên các môn học được dạy trong niên khóa 2011-2012.
SELECT DISTINCT m.TenMH 
FROM MONHOC m
JOIN GIANGDAY g ON m.MaMH = g.MaMH
WHERE g.NienKhoa = '2011-2012';

-- CAU: 10 - Khoa + SV theo từng khoa, sắp xếp A-Z theo tên sinh viên
-- BUG: Có 2 câu SELECT liên tiếp: câu đầu (không ORDER BY, không bí danh bảng) là bản nháp thừa → sinh thêm
--      một bảng kết quả; chỉ câu thứ 2 mới đúng yêu cầu. Nên xóa câu đầu.
-- NOTE: INNER JOIN KHOA - SINHVIEN theo MaKhoa; SV không có khoa sẽ bị loại. Hai kiểu đặt bí danh cột: Ten
--       AS 'Tên Sinh Viên' và 'Tên Sinh Viên' = Ten (kiểu riêng của T-SQL).
-- NOTE: ORDER BY Ten sắp theo cả chuỗi (bắt đầu từ HỌ), không phải theo tên riêng.
-- 10. Cho biết tên khoa, mã số sinh viên, tên, địa chỉ của các SV theo từng Khoa sắp theo thứ tự A-Z của tên sinh viên.
SELECT TenKhoa, MSSV, Ten as 'Tên Sinh Viên', DiaChi 
FROM KHOA  INNER JOIN SINHVIEN ON KHOA.MaKhoa=SINHVIEN.MaKhoa
SELECT K.MaKHoa,TenKhoa, MSSV, 'Tên Sinh Viên' = Ten, DiaChi 
FROM KHOA K  INNER JOIN SINHVIEN S ON K.MaKhoa=S.MaKhoa
ORDER BY Ten
GO

-- CAU: 11 - Tên môn, tên SV, điểm tổng kết của từng lượt học
-- NOTE: Đường nối 4 bảng: KETQUA → SINHVIEN (MSSV) và KETQUA → GIANGDAY (MaKhoaHoc) → MONHOC (MaMH).
--       GIANGDAY là cầu nối để từ kết quả biết được môn học. Kết quả: 10 dòng (mỗi dòng KETQUA ra 1 dòng).
-- 11. Cho biết tên môn học, tên sinh viên, điểm tổng kết (DiemKhoaHoc) của sinh viên qua từng khóa học.
SELECT m.TenMH, s.Ten, kq.DiemKhoaHoc 
FROM KETQUA kq
JOIN SINHVIEN s ON kq.MSSV = s.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
JOIN MONHOC m ON g.MaMH = m.MaMH;
GO

-- CAU: 12 - SV học môn 'CSDL' có điểm tổng kết từ 6 đến 7
-- NOTE: Lọc môn ngay bằng g.MaMH = 'CSDL' nên không cần JOIN MONHOC. BETWEEN 6 AND 7 gồm cả hai đầu mút →
--       Bùi Thúy An (6.4); Nguyễn Thanh Tùng (5.8) bị loại.
--12.	Cho biết tên và điểm tổng kết của sinh viên qua từng khóa học (DiemKhoaHoc) của các SV học môn ‘CSDL’ với DiemKhoaHoc từ 6 đến 7.
SELECT s.Ten, kq.DiemKhoaHoc 
FROM KETQUA kq
JOIN SINHVIEN s ON kq.MSSV = s.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
WHERE g.MaMH = 'CSDL' AND kq.DiemKhoaHoc BETWEEN 6 AND 7;
GO

-- CAU: 13 - Kết quả của SV tên 'TUNG'
-- NOTE: Tên lưu có dấu (Tùng) nên dùng OR: LIKE N'%Tùng' (có dấu) hoặc LIKE '%TUNG%' (không dấu). Dấu % đầu
--       = bỏ qua họ và tên đệm. → 1 dòng (khóa K001, điểm 5.8).
--13.	Cho biết Tên sinh viên, tên môn học, mã khóa học, điểm tổng kết của sinh viên qua từng khóa học (DiemKhoaHoc) của SV có tên là ‘TUNG’.
SELECT s.Ten, m.TenMH, g.MaKhoaHoc, kq.DiemKhoaHoc 
FROM KETQUA kq
JOIN SINHVIEN s ON kq.MSSV = s.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
JOIN MONHOC m ON g.MaMH = m.MaMH
WHERE s.Ten LIKE N'%Tùng' OR s.Ten LIKE '%TUNG%';
GO

-- CAU: 14 - Khoa nào có SV đã học những môn nào
-- NOTE: Chuỗi JOIN 5 bảng: SINHVIEN → KHOA và SINHVIEN → KETQUA → GIANGDAY → MONHOC. DISTINCT gộp các dòng
--       trùng (cùng khoa + cùng môn) để mỗi cặp (khoa, môn) chỉ xuất hiện 1 lần.
-- 14.	Cho biết tên khoa, tên môn học mà những sinh viên trong khoa đã học. Yêu cầu khi kết quả có nhiều dòng trùng nhau, chỉ hiển thị 1 dòng làm đại diện
SELECT DISTINCT k.TenKhoa, m.TenMH 
FROM SINHVIEN s
JOIN KHOA k ON s.MaKhoa = k.MaKhoa
JOIN KETQUA kq ON s.MSSV = kq.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
JOIN MONHOC m ON g.MaMH = m.MaMH;
GO

-- CAU: 15 - Khoa và mã khóa học mà giáo viên của khoa có tham gia giảng dạy
-- NOTE: GIAOVIEN nối KHOA (GV thuộc khoa nào) và nối GIANGDAY (GV dạy khóa nào) → suy ra cặp (khoa, khóa
--       học). "Khoa" ở đây là khoa của GIÁO VIÊN, không phải khoa của môn.
--15.	Cho biết tên khoa, mã khóa học mà giáo viên của khoa có tham gia giảng dạy.
SELECT DISTINCT k.TenKhoa, g.MaKhoaHoc 
FROM GIAOVIEN gv
JOIN KHOA k ON gv.MaKhoa = k.MaKhoa
JOIN GIANGDAY g ON gv.MaGV = g.MaGV;
GO

-- CAU: 16 - Giáo viên dạy môn 'Kỹ thuật lập trình'
-- NOTE: GIAOVIEN → GIANGDAY → MONHOC, lọc TenMH bằng dấu = (so khớp chính xác, có N). Đề ghi không dấu
--       nhưng code dùng đúng tên có dấu như trong dữ liệu → Hoàng Vương (C04M).
--16.	Cho biết tên những giáo viên tham gia giảng dạy môn “Ky thuat lap trinh”.
SELECT DISTINCT gv.TenGV 
FROM GIAOVIEN gv
JOIN GIANGDAY g ON gv.MaGV = g.MaGV
JOIN MONHOC m ON g.MaMH = m.MaMH
WHERE m.TenMH = N'Kỹ thuật lập trình';
GO

-- CAU: 17 - SV có ít nhất một môn điểm tổng kết > 8
-- NOTE: Điều kiện nằm trên từng dòng KETQUA (DiemKhoaHoc > 8) nên SV chỉ cần 1 môn > 8. DISTINCT tránh lặp
--       SV (C0001F có 2 dòng 8.6). → C0001F, T0005M.
-- NOTE: Các dòng '-- (i)' / '-- (ii)' ngay bên dưới là ĐỀ BÀI của câu 18-19 (mỗi câu phải viết 2 cách),
--       không phải code.
--17.	Cho biết mã, tên các SV có DiemKhoaHoc của 1 môn học nào đó trên 8 (kết quả các môn khác có thể <=8).
-- 	Yêu cầu hai câu 18 và 19 sau đây, mỗi câu sẽ được viết bằng 2 cách: 
SELECT DISTINCT s.MSSV, s.Ten 
FROM SINHVIEN s
JOIN KETQUA kq ON s.MSSV = kq.MSSV
WHERE kq.DiemKhoaHoc > 8;
-- (i).-	Sử dụng 1 lệnh SELECT
-- (ii).-	 Sử dụng từ 2 lệnh SELECT trở lên và các lệnh này được kết với nhau qua 1 trong 2 toán tử INTERSECT hoặc UNION.

-- CAU: 18 - Tên SV, mã môn, tên môn, điểm của SV đã học môn 'CSDL' hoặc 'CTDL'
-- CACH: Cách (ii) đang dùng: WHERE MSSV IN (SELECT ... UNION SELECT ...). Hai sub-select lấy MSSV của SV
--       học CSDL và của SV học CTDL; UNION gộp + loại trùng (tương đương OR). Muốn "học CẢ HAI môn" phải
--       dùng INTERSECT.
-- BUG: Truy vấn ngoài lại JOIN toàn bộ KETQUA của các SV đó nên in cả môn khác (vd C0001F có KTLT, CWIN)
--      chứ không chỉ CSDL/CTDL. Nếu đề chỉ muốn 2 môn này, thêm WHERE M.MaMH IN ('CSDL', 'CTDL') ở truy vấn
--      ngoài.
-- TODO: Chưa có cách (i) - dùng đúng 1 SELECT: JOIN 4 bảng + WHERE M.MaMH = 'CSDL' OR M.MaMH = 'CTDL' (hoặc
--       IN).
-- 18.	Cho biết tên sinh viên, mã môn học, tên môn học, DiemKhoaHoc của những SV đã học môn ‘CSDL’ hoặc ‘CTDL’.
SELECT Ten, M.MaMH, TenMH, DiemKhoaHoc
FROM SINHVIEN SV JOIN KETQUA KQ ON SV.MSSV = KQ.MSSV
				JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
				JOIN MonHoc M ON M.MaMH=GD.MaMH
WHERE SV.MSSV IN 
(SELECT MSSV
FROM KETQUA KQ JOIN GIANGDAY G ON KQ.MaKhoaHoc = G.MaKhoaHoc
WHERE G.MaMH = 'CSDL' 
UNION
SELECT MSSV
FROM KETQUA KQ JOIN GIANGDAY G ON KQ.MaKhoaHoc = G.MaKhoaHoc
WHERE G.MaMH = 'CTDL')

-- CAU: 19 - Môn học mà GV 'Trần Văn Tiến' dạy ở học kỳ 1 niên khóa 2012-2013
-- TODO: Chưa có code (cả 2 cách). Gợi ý cách (i): JOIN GIAOVIEN - GIANGDAY - MONHOC, WHERE TenGV = N'Trần
--       Văn Tiến' AND HocKy = 1 AND NienKhoa = '2012-2013' → CTDL (K003). Cách (ii): INTERSECT giữa tập môn
--       của GV và tập môn của học kỳ/niên khóa đó.
-- 19.	Cho biết tên môn học mà giáo viên “Tran Van Tien” tham gia giảng dạy trong học kỳ 1 niên khóa 2012-2013.

-- CAU: 20 - Tên SV đã có điểm trong KETQUA (loại tên trùng)
-- NOTE: INNER JOIN SINHVIEN - KETQUA chỉ giữ SV có ít nhất 1 dòng điểm (loại Hoàng Thị Hoa). DISTINCT vì SV
--       có nhiều dòng điểm. → 4 SV.
-- 20. Cho biết tên những sinh viên đã có điểm trong table Kết quả (yêu cầu loại bỏ các tên trùng nhau nếu có).
SELECT DISTINCT S.Ten AS N'Tên Sinh Viên'
FROM SINHVIEN S 
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV;
GO

-- CAU: 21 - Hiển thị 35% dữ liệu bảng KETQUA
-- NOTE: TOP n PERCENT lấy n% số dòng và làm tròn LÊN: 35% x 10 = 3.5 → 4 dòng. Không có ORDER BY nên 4 dòng
--       nào được lấy là tùy ý (không đảm bảo thứ tự).
-- 21. Cho hiển thị 35% dữ liệu có trong table kết quả.
SELECT TOP 35 PERCENT KQ.* FROM KETQUA KQ;
GO


-- CAU: 22 - 3 sinh viên có điểm tổng kết cao nhất
-- NOTE: ORDER BY điểm giảm dần + TOP (3) WITH TIES = lấy 3 dòng đầu và THÊM mọi dòng có điểm bằng dòng thứ
--       3. WITH TIES bắt buộc phải đi cùng ORDER BY.
-- BUG: TOP tính theo DÒNG chứ không theo SV: C0001F có 2 dòng 8.6 nên 3 dòng đầu chỉ ra 2 SV (T0005M 8.8,
--      C0001F 8.6 x2). Muốn 3 SV khác nhau phải gộp theo SV (MAX điểm mỗi SV) rồi mới TOP 3.
-- NOTE: Câu 2 thêm DISTINCT: loại cặp (Tên, Điểm) trùng rồi mới lấy TOP (DISTINCT chạy trước TOP). Hai ghi
--       chú "← sửa" trong code là chỗ bạn đã sửa lỗi cú pháp.
-- 22. Cho biết tên 3 sinh viên có DiemKhoaHoc cao nhất trong table kết quả.
-- Câu 1: top 3 điểm cao nhất, kèm các dòng đồng hạng
SELECT TOP (3) WITH TIES
       S.Ten           AS [Tên Sinh Viên],
       KQ.DiemKhoaHoc  AS [Điểm Khóa Học]
FROM SINHVIEN S
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
ORDER BY KQ.DiemKhoaHoc DESC;
GO

-- Câu 2: tương tự nhưng có DISTINCT (loại trùng tên+điểm)
SELECT DISTINCT TOP (3) WITH TIES
       SV.Ten,
       KQ.DiemKhoaHoc
FROM KETQUA KQ
JOIN SINHVIEN SV ON KQ.MSSV = SV.MSSV      -- ← sửa: SV.MSSV, không phải KQ.MSSV
ORDER BY KQ.DiemKhoaHoc DESC;              -- ← bỏ ngoặc đơn bao ngoài
GO

-- CAU: 23 - Môn có điểm cao nhất của SV 'C0001F' (đồng điểm thì liệt kê hết)
-- NOTE: Lọc SV C0001F → ORDER BY điểm giảm dần → TOP 1 WITH TIES giữ dòng đầu và mọi dòng cùng điểm. → 2
--       môn cùng 8.6: Cấu trúc dữ liệu (K003) và Lập trình C trên Windows (K004).
--23.	Cho biết tên môn học và điểm lớn nhất mà sinh viên ‘C0001F’ đạt được. Nếu sinh viên ‘C0001F’ có nhiều môn có cùng điểm lớn nhất (ví dụ cùng đạt 8.6), hãy liệt kê tất cả những môn học này.
SELECT TOP 1 WITH TIES M.TenMH AS N'Tên Môn Học', KQ.DiemKhoaHoc AS N'Điểm Lớn Nhất'
FROM KETQUA KQ JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
JOIN MONHOC M ON GD.MaMH = M.MaMH
WHERE KQ.MSSV = 'C0001F'
ORDER BY KQ.DiemKhoaHoc DESC
GO

-- CAU: 24 - SV khoa Toán có điểm lớn hơn TẤT CẢ điểm của SV ngoài khoa Toán
-- NOTE: Điều kiện > (SELECT MAX(...)) tương đương > ALL: điểm phải vượt điểm cao nhất của nhóm kia.
--       Sub-query lấy MAX điểm của SV có MaKhoa <> 'TOAN' (= 8.6 của C0001F). → Trần Hồng Sơn (8.8).
-- NOTE: Sub-query này độc lập (không tham chiếu truy vấn ngoài) nên chỉ chạy 1 lần.
--24.	Cho biết tên những sinh viên thuộc khoa Toán có DiemKhoaHoc lớn hơn tất cả các điểm của những SV không thuộc khoa Toán.
SELECT DISTINCT S.Ten AS N'Tên Sinh Viên'
FROM SINHVIEN S JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE S.MaKhoa = 'TOAN' AND KQ.DiemKhoaHoc > (
    SELECT MAX(DiemKhoaHoc) 
    FROM KETQUA K JOIN SINHVIEN V ON K.MSSV = V.MSSV 
    WHERE V.MaKhoa <> 'TOAN'
)
GO

-- CAU: 25 - SV ngoài khoa CNTT có năm sinh nhỏ hơn năm sinh của BẤT KỲ SV nào khoa CNTT
-- TODO: Chưa có code. Gợi ý: WHERE MaKhoa <> 'CNTT' AND YEAR(NgaySinh) < ANY (SELECT YEAR(NgaySinh) FROM
--       SINHVIEN WHERE MaKhoa = 'CNTT'). '< ANY' = nhỏ hơn ÍT NHẤT MỘT giá trị (tức nhỏ hơn MAX).
-- 25.	Cho biết tên những sinh viên không thuộc khoa Công nghệ thông tin có năm sinh nhỏ hơn năm sinh của bất kỳ SV nào thuộc khoa Công nghệ thông tin.

-- CAU: 26 - Tên khoa có sinh viên theo học (3 cách)
-- TODO: Chưa có code cả 3 cách: (i) JOIN KHOA - SINHVIEN + DISTINCT; (ii) WHERE MaKhoa IN (SELECT MaKhoa
--       FROM SINHVIEN); (iii) WHERE EXISTS (SELECT 1 FROM SINHVIEN S WHERE S.MaKhoa = K.MaKhoa).
-- 26.	Cho biết tên những khoa có sinh viên theo học. Lần lượt thực hiện yêu cầu này bằng các cách:
-- (i).-	Không sử dụng sub Select.
-- (ii).-	Sử dụng sub Select và toán tử IN.
-- (iii).-	Sử dụng sub Select và toán tử EXISTS.

-- CAU: 27 (*) - Cặp SV có cùng tháng sinh (kết nối bảng với chính nó - self join)
-- NOTE: Dùng cùng một bảng 2 lần với bí danh S1 (SV X) và S2 (SV Y). MONTH(S1.NgaySinh) =
--       MONTH(S2.NgaySinh) chỉ so THÁNG, không so năm.
-- NOTE: WHERE S1.MSSV < S2.MSSV loại cặp tự ghép với chính nó (A-A) và loại cặp đảo (B-A), nên mỗi cặp chỉ
--       ra 1 lần. Kết quả mẫu: Bùi Thúy An & Nguyễn Thành Long (cùng sinh tháng 8).
-- 27.	(*) Cho biết tên những sinh viên có tháng sinh trùng nhau. Kết quả hiển thị gồm tên sinh viên (X), ngày sinh của sinh viên (X), tên sinh viên (Y) trùng tháng sinh với sinh viên X,  ngày sinh của sinh viên (Y). Thực hiện liên kết các table tham gia bằng 2 cách:

-- CACH: (i) INNER JOIN ... ON <điều kiện nối> - cú pháp chuẩn, điều kiện nối nằm ở ON.
-- (i).-	Inner join
SELECT S1.Ten AS N'Tên SV (X)', S1.NgaySinh AS N'Ngày Sinh (X)', 
       S2.Ten AS N'Tên SV (Y)', S2.NgaySinh AS N'Ngày Sinh (Y)'
FROM SINHVIEN S1 JOIN SINHVIEN S2 ON MONTH(S1.NgaySinh) = MONTH(S2.NgaySinh)
WHERE S1.MSSV < S2.MSSV;
GO

-- CACH: (ii) "Phép nhân": FROM A, B (tích Descartes) rồi lọc bằng WHERE - cho kết quả y hệt (i) nhưng là cú
--       pháp cũ; quên điều kiện nối sẽ ra hàng loạt dòng thừa.
-- (ii).-	Phép nhân
SELECT S1.Ten AS N'Tên SV (X)', S1.NgaySinh AS N'Ngày Sinh (X)', 
       S2.Ten AS N'Tên SV (Y)', S2.NgaySinh AS N'Ngày Sinh (Y)'
FROM SINHVIEN S1, SINHVIEN S2
WHERE MONTH(S1.NgaySinh) = MONTH(S2.NgaySinh) AND S1.MSSV < S2.MSSV;
GO

-- CAU: 28 - Ba hàm xếp hạng ROW_NUMBER / RANK / DENSE_RANK
-- NOTE: Cú pháp: hàm() OVER (ORDER BY ...). Cả 3 xếp theo điểm giảm dần, khác nhau ở cách xử lý đồng điểm.
-- NOTE: Điểm sắp giảm dần: 8.8, 8.6, 8.6, 7.8, 7.8, 7.8, 6.4, 5.8, 4.4, 3.9. ROW_NUMBER:
--       1,2,3,4,5,6,7,8,9,10 (luôn khác nhau). RANK: 1,2,2,4,4,4,7,8,9,10 (đồng hạng cùng số, BỎ số kế
--       tiếp). DENSE_RANK: 1,2,2,3,3,3,4,5,6,7 (đồng hạng, KHÔNG bỏ số).
-- 28.	Lần lượt sử dụng các hàm xếp hạng: Row_Number, Dense_Rank, Rank để xuất các kết quả sau:
SELECT S.Ten, KQ.DiemKhoaHoc,
    ROW_NUMBER() OVER(ORDER BY KQ.DiemKhoaHoc DESC) AS N'Row_Number',
    RANK() OVER(ORDER BY KQ.DiemKhoaHoc DESC) AS N'Rank',
    DENSE_RANK() OVER(ORDER BY KQ.DiemKhoaHoc DESC) AS N'Dense_Rank'
FROM SINHVIEN S JOIN KETQUA KQ ON S.MSSV = KQ.MSSV;
GO

-- ================================================================================================
-- SECTION: 5. HÀM TỔNG HỢP - GROUP BY - HAVING (câu 29 → 49)
-- ================================================================================================
-- NOTE: COUNT / SUM / AVG / MIN / MAX gộp nhiều dòng thành 1 giá trị. COUNT(cột) bỏ qua NULL, COUNT(*) đếm
--       mọi dòng. Khi có GROUP BY, mọi cột trong SELECT không nằm trong hàm tổng hợp phải có trong GROUP
--       BY.
-- NOTE: Thứ tự thực thi: FROM/JOIN → WHERE (lọc DÒNG) → GROUP BY → HAVING (lọc NHÓM) → SELECT → ORDER BY.
-- 3.3.2.	Aggregate Functions

-- CAU: 29 - Có bao nhiêu sinh viên
-- NOTE: COUNT(MSSV) đếm số giá trị không NULL của khóa chính → 5.
--29.	Có bao nhiêu SV.
SELECT COUNT(MSSV) AS N'Số Lượng SV' FROM SINHVIEN;
GO

-- CAU: 30 - Có bao nhiêu giáo viên
-- NOTE: Tương tự câu 29 → 5.
--30.	Có bao nhiêu GV.
SELECT COUNT(MaGV) AS N'Số Lượng GV' FROM GIAOVIEN;
GO

-- CAU: 31 - Có bao nhiêu giáo viên khoa CNTT
-- NOTE: WHERE lọc trước, COUNT đếm sau → 3 (C01F, C03M, C04M).
--31.	Có bao nhiêu giáo viên khoa CNTT.
SELECT COUNT(MaGV) AS N'Số GV CNTT' 
FROM GIAOVIEN 
WHERE MaKhoa = 'CNTT';
GO

-- CAU: 32 - Có bao nhiêu SV nữ thuộc khoa CNTT
-- NOTE: WHERE MaKhoa = CNTT AND PhaiNu = 1 → 2 (C0001F, C0004F).
--32.	Có bao nhiêu SV nữ thuộc khoa “CNTT”.
SELECT COUNT(MSSV) AS N'Số SV Nữ CNTT' 
FROM SINHVIEN 
WHERE MaKhoa = 'CNTT' AND PhaiNu = 1;
GO

-- CAU: 33 - Số môn học được giảng dạy trong học kỳ 1 năm 2011-2012
-- NOTE: COUNT(DISTINCT MaMH): CSDL mở 2 khóa (K001, K006) nhưng chỉ đếm 1 lần → 4 môn (CSDL, CTDL, TRR,
--       LTDT). K002 thuộc học kỳ 2 nên bị loại.
--33.	Có bao nhiêu môn học được giảng dạy trong học kỳ I năm 2011-2012.
SELECT COUNT(DISTINCT MaMH) AS N'Số Môn Học' 
FROM GIANGDAY 
WHERE HocKy = 1 AND NienKhoa = '2011-2012';
GO

-- CAU: 34 - Có bao nhiêu SV học môn CSDL
-- NOTE: JOIN KETQUA - GIANGDAY, lọc MaMH = 'CSDL', COUNT(DISTINCT MSSV) → 2 (C0001F, C0002M). DISTINCT để
--       không đếm 2 lần nếu một SV học CSDL ở nhiều khóa.
--34.	Có bao nhiêu SV học môn CSDL.
SELECT COUNT(DISTINCT KQ.MSSV) AS N'Số SV Học CSDL'
FROM KETQUA KQ JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
WHERE GD.MaMH = 'CSDL';
GO

-- CAU: 35 - Số môn đã học và điểm TB của SV 'T0003M'
-- NOTE: COUNT(MaKhoaHoc) + ROUND(AVG(DiemKhoaHoc), 2) = (7.8 + 3.9 + 4.4) / 3 = 5.37 → 3 môn, ĐTB 5.37.
--       Không cần GROUP BY vì sau WHERE chỉ còn 1 SV.
--35.	Cho biết số lượng môn học đã tham gia và điểm TB của tất cả các DiemKhoaHoc của SV có mã số ‘T0003M’.
SELECT COUNT(MaKhoaHoc) AS N'Số Môn Tham Gia', ROUND(AVG(DiemKhoaHoc), 2) AS N'Điểm TB'
FROM KETQUA
WHERE MSSV = 'T0003M';
GO

-- CAU: 36 - Mã, tên, địa chỉ và điểm TB của từng SV (kể cả SV chưa có điểm)
-- NOTE: LEFT JOIN giữ mọi SV; SV không có điểm thì phía KETQUA = NULL → AVG = NULL (Hoàng Thị Hoa). GROUP
--       BY phải đủ MSSV, Ten, DiaChi. Vd C0001F = (6.4 + 8.6 + 7.8 + 8.6) / 4 = 7.85.
--36.	Cho biết mã, tên, địa chỉ và điểm TB của tất cả các DiemKhoaHoc của từng SV.
SELECT S.MSSV, S.Ten, S.DiaChi, ROUND(AVG(KQ.DiemKhoaHoc), 2) AS N'Điểm TB'
FROM SINHVIEN S LEFT JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten, S.DiaChi;
GO

-- CAU: 37 - Số điểm >= 8 của từng sinh viên (chỉ SV có điểm >= 8)
-- NOTE: WHERE lọc DÒNG trước khi gom nhóm → chỉ SV có ít nhất 1 điểm >= 8 mới xuất hiện: C0001F = 2, T0005M
--       = 1. SV không có điểm >= 8 biến mất (câu 71 sửa bằng LEFT JOIN).
--37.	Cho biết số lượng DiemKhoaHoc >=8 của từng sinh viên (chỉ xuất kết quả cho những sinh viên có DiemKhoaHoc >=8).
SELECT S.Ten AS N'Tên Sinh Viên', COUNT(KQ.MaKhoaHoc) AS N'Số Môn Điểm >= 8'
FROM SINHVIEN S JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE KQ.DiemKhoaHoc >= 8
GROUP BY S.MSSV, S.Ten;
GO

-- CAU: 38 - Tên khoa + số SV của từng khoa (chỉ khoa có SV)
-- NOTE: INNER JOIN nên khoa không có SV (SINH) không hiện (câu 69 hiện đủ). Kết quả mẫu: CNTT 3, Toán 2.
-- BUG: Bí danh cột đặt nhầm là 'SL Khoá Học' (copy từ câu 39) - đúng ra phải là số SINH VIÊN.
-- NOTE: GROUP BY TenKhoa vẫn đúng ở đây, nhưng hai khoa trùng tên sẽ bị gộp; chuẩn hơn là GROUP BY MaKhoa,
--       TenKhoa.
--38 Cho biết tên khoa, số lượng sinh viên có trong từng khoa (chỉ xuất kết quả cho những khoa có sinh viên).
SELECT K.TenKhoa, COUNT(SV.MSSV) AS N'SL Khoá Học'
FROM Khoa K
JOIN SinhVien SV ON SV.MaKhoa = K.MaKhoa
GROUP BY K.TenKhoa
GO

-- CAU: 39 - Tên khoa + số khóa học mà GV của khoa có dạy (chỉ khoa có GV dạy)
-- NOTE: JOIN KHOA - GIAOVIEN - GIANGDAY, COUNT(DISTINCT MaKhoaHoc): CNTT 8, TOAN 1. Khoa SINH (không có GV)
--       không hiện (câu 70 bổ sung đủ khoa).
-- 39.	Cho biết tên khoa, số lượng khóa học mà giáo viên của khoa có tham gia giảng dạy (chỉ xuất kết quả cho những khoa có giáo viên tham gia giảng dạy trong các khóa học).
SELECT  K.TenKhoa, COUNT(DISTINCT GD.MaKhoaHoc) AS N'SL Khóa Học'
FROM Khoa K
JOIN GiaoVien GV ON K.MaKhoa = GV.MaKhoa
JOIN GiangDay GD ON GV.MaGV = GD.MaGV
GROUP BY K.MaKhoa, K.TenKhoa
GO

-- CAU: 40 - Số tín chỉ lý thuyết / thực hành mà từng SV đã tham gia
-- NOTE: Dùng BẢNG DẪN XUẤT (derived table = sub-query trong FROM, đặt bí danh T): bên trong GROUP BY MSSV
--       rồi SUM(SoTCLT), SUM(SoTCTH); bên ngoài JOIN SINHVIEN để lấy tên. Tách bước gom nhóm khỏi bước lấy
--       tên giúp khỏi phải GROUP BY thêm cột.
-- NOTE: INNER JOIN nên SV chưa học không hiện (câu 67 hiện cả SV chưa học).
-- 40. Cho biết số lượng tín chỉ lý thuyết, số lượng tín chỉ thực hành mà từng sinh viên đã tham gia (gồm MSSV, tên SV, số lượng tín chỉ lý thuyết, số lượng tín chỉ thực hành).
SELECT S.MSSV, S.Ten AS N'Tên Sinh Viên', 
       T.TongTCLT, T.TongTCTH
FROM SINHVIEN S
INNER JOIN (
    SELECT KQ.MSSV, 
           SUM(GD.SoTCLT) AS TongTCLT, 
           SUM(GD.SoTCTH) AS TongTCTH
    FROM KETQUA KQ
    INNER JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
    GROUP BY KQ.MSSV
) T ON S.MSSV = T.MSSV;
GO

-- CAU: 41 - Mỗi giáo viên: số khóa học và tổng tín chỉ đã dạy
-- NOTE: Cùng mẫu bảng dẫn xuất nhưng LEFT JOIN từ GIAOVIEN để GV chưa dạy khóa nào vẫn hiện; ISNULL(..., 0)
--       đổi NULL thành 0 (Thanh Trà = 0 khóa, 0 tín chỉ).
-- 41. Cho biết tên tất cả các giáo viên cùng với số lượng khóa học, số lượng tín chỉ (lý thuyết + thực hành) mà từng giáo viên đã tham gia giảng dạy. 
SELECT GV.TenGV, 
       ISNULL(T.SoLuongKhoaHoc, 0) AS SoLuongKhoaHoc, 
       ISNULL(T.TongSoTinChi, 0) AS TongSoTinChi
FROM GIAOVIEN GV
LEFT JOIN (
    SELECT MaGV, 
           COUNT(MaKhoaHoc) AS SoLuongKhoaHoc, 
           SUM(TongSoTC) AS TongSoTinChi
    FROM GIANGDAY
    GROUP BY MaGV
) T ON GV.MaGV = T.MaGV;
GO

-- CAU: 42 - Thống kê số SV theo từng nhóm điểm (điểm làm tròn không lấy số lẻ)
-- NOTE: ROUND(DiemKhoaHoc, 0) làm tròn về số nguyên (7.8 → 8) và dùng làm khóa nhóm; GROUP BY phải lặp lại
--       đúng biểu thức ROUND. COUNT(DISTINCT MSSV) → SV có nhiều điểm cùng nhóm chỉ tính 1 lần. WHERE ...
--       IS NOT NULL bỏ các dòng chưa có điểm.
-- 42. Giả sử người ta muốn thống kê số lượng sinh viên theo từng nhóm điểm (với nhóm điểm được làm tròn không lấy số lẻ từ DiemKhoaHoc trong table Kết quả): 
-- Yêu cầu: Đếm xem mỗi nhóm trong DiemKhoaHoc_PhanNhom có bao nhiêu sinh viên.
SELECT ROUND(DiemKhoaHoc, 0) AS DiemKhoaHoc_PhanNhom, 
       COUNT(DISTINCT MSSV) AS SoLuongSinhVien
FROM KETQUA
WHERE DiemKhoaHoc IS NOT NULL
GROUP BY ROUND(DiemKhoaHoc, 0);
GO

-- CAU: 43 - SV chỉ mới thi đúng một môn
-- NOTE: HAVING COUNT(...) = 1 lọc SAU khi gom nhóm (WHERE không dùng được với hàm tổng hợp). → Nguyễn Thanh
--       Tùng (C0002M, chỉ có khóa K001).
-- 43. Cho biết tên những sinh viên chỉ mới thi đúng một môn.
SELECT S.Ten AS N'Tên Sinh Viên'
FROM SINHVIEN S
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten
HAVING COUNT(KQ.MaKhoaHoc) = 1;
GO

-- CAU: 44 - SV có điểm trung bình (của mọi DiemKhoaHoc) > 8.5
-- BUG: SAI LOGIC: GROUP BY có cả KQ.DiemKhoaHoc nên mỗi nhóm chỉ 1 dòng, AVG(...) chính là điểm đó; thực
--      chất truy vấn đang lọc TỪNG DÒNG điểm > 8.5 (ra C0001F 8.6, T0005M 8.8) chứ không phải điểm TRUNG
--      BÌNH. ĐTB thật: C0001F 7.85, T0005M 8.3 ... → đúng ra KHÔNG có SV nào > 8.5.
-- TODO: Sửa: GROUP BY SV.MSSV, SV.Ten, SV.DiaChi + HAVING AVG(KQ.DiemKhoaHoc) > 8.5, và SELECT
--       AVG(KQ.DiemKhoaHoc) AS DiemTB (bỏ KQ.DiemKhoaHoc khỏi GROUP BY).
-- 44.	Cho biết mã, tên, địa chỉ và điểm của các SV có điểm trung bình (của tất cả các DiemKhoaHoc) >8.5.
SELECT SV.MSSV, SV.Ten, SV.DiaChi, KQ.DiemKhoaHoc
FROM SinhVien SV
JOIN KetQua KQ ON KQ.MSSV = SV.MSSV
GROUP BY SV.MSSV, SV.Ten, SV.DiaChi, KQ.DiemKhoaHoc
HAVING AVG(KQ.DiemKhoaHoc) > 8.5
GO

-- CAU: 45 - Khóa học có từ 2 đến 4 SV tham gia
-- FIXME: Sai tên cột 'NieuKhoa' (2 chỗ: SELECT và GROUP BY) → lỗi "Invalid column name". Đúng là NienKhoa.
-- NOTE: HAVING COUNT(KQ.MSSV) BETWEEN 2 AND 4 giữ khóa có 2-4 SV: K001 = 2, K002 = 2, K003 = 3, K004 = 2
--       (K005 chỉ 1 SV nên bị loại).
-- 45.	Cho biết Mã khóa học, học kỳ, năm, số lượng SV tham gia của những khóa học có số lượng SV tham gia từ 2 đến 4 người.
SELECT GD.MaKhoaHoc, GD.HocKy, GD.NieuKhoa, COUNT(KQ.MSSV) AS SLSV
FROM GiangDay GD
JOIN KetQua KQ ON KQ.MaKhoaHoc = GD.MaKhoaHoc
GROUP BY GD.MaKhoaHoc, GD.HocKy, GD.NieuKhoa
HAVING COUNT(KQ.MSSV) BETWEEN 2 AND 4

-- CAU: 47 - Trả lời "Có" / "Không" bằng CASE WHEN EXISTS
-- NOTE: EXISTS (sub-query) = TRUE nếu sub-query trả về ít nhất 1 dòng; SELECT 1 chỉ để có cột, nội dung
--       không quan trọng. CASE đổi TRUE/FALSE thành chữ N'Có' / N'Không'. Mỗi câu cho ra 1 ô kết quả.
-- 47. Trả lời “Có” hoặc “Không”

-- CAU: 47a - SV 'C0001F' có học khóa 'K001' không?
-- NOTE: Có dòng KETQUA (C0001F, K001) → "Có".
-- a. Cho biết sinh viên có mã số ‘C0001F’ có tham gia khóa học ‘K001’ hay không?
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 
        FROM KETQUA 
        WHERE MSSV = 'C0001F' AND MaKhoaHoc = 'K001'
    ) 
    THEN N'Có' ELSE N'Không' END AS [47a];

-- CAU: 47b - Khóa K001 có SV phải thi lại (điểm < 5) không?
-- NOTE: Đề ghi 'K1' = 'K001' trong dữ liệu. K001 có điểm 6.4 và 5.8, không điểm nào < 5 → "Không".
-- b. Cho biết khóa học K1 (tương ứng với 'K001' trong dữ liệu) có sinh viên bị thi lại (DiemKhoaHoc <5) hay không? 
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 
        FROM KETQUA 
        WHERE MaKhoaHoc = 'K001' AND DiemKhoaHoc < 5
    ) 
    THEN N'Có' ELSE N'Không' END AS [47b]

-- CAU: 47c - Khoa CNTT có SV nữ đạt >= 5 ở CẢ 2 môn 'CSDL' & 'CTDL' không?
-- NOTE: Lọc SV nữ CNTT + điểm >= 5 ở 2 môn, rồi GROUP BY MSSV HAVING COUNT(DISTINCT MaMH) = 2 để bắt buộc
--       đạt CẢ HAI môn (chỉ dùng IN thì đạt 1 môn cũng qua). C0001F đạt (6.4 và 8.6) → "Có".
-- c. Cho biết Khoa CNTT có sinh viên Nữ đạt DiemKhoaHoc cả 2 môn ‘CSDL’ & ’CTDL’ >= 5 hay không?  
SELECT 
    CASE WHEN EXISTS (
        SELECT S.MSSV
        FROM SINHVIEN S
        JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
        JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
        WHERE S.MaKhoa = 'CNTT' AND S.PhaiNu = 1 
          AND GD.MaMH IN ('CSDL', 'CTDL') 
          AND KQ.DiemKhoaHoc >= 5
        GROUP BY S.MSSV
        HAVING COUNT(DISTINCT GD.MaMH) = 2
    ) 
    THEN N'Có' ELSE N'Không' END AS [Trả Lời 47c]

-- CAU: 47d - Giáo viên tên 'THAO' có dạy môn nào trong 2011-2012 không?
-- NOTE: Dùng LIKE N'%Thảo' OR '%THAO%' để bắt cả tên có dấu lẫn không dấu. Phạm Thị Thảo dạy K001
--       (2011-2012) → "Có".
-- d. Cho biết giáo viên tên 'THAO' có dạy môn học nào trong năm 2011-2012 hay không?  
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 
        FROM GIAOVIEN GV
        JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
        WHERE (GV.TenGV LIKE N'%Thảo' OR GV.TenGV LIKE '%THAO%')
          AND GD.NienKhoa = '2011-2012'
    ) 
    THEN N'Có' ELSE N'Không' END AS [47d]

-- CAU: 48 - MSSV, họ tên, học bổng (ĐTB >= 7 được 1.000.000, ngược lại 0)
-- NOTE: CASE đặt trong SELECT được tính cho từng nhóm (từng SV) nhờ GROUP BY; AVG(...) dùng được ngay trong
--       CASE. Mẫu: C0001F 7.85 → 1tr, T0005M 8.3 → 1tr, T0003M 5.37 → 0, C0002M 5.8 → 0. SV không có điểm
--       không hiện (INNER JOIN).
-- 48. Tạo dữ liệu 3 cột MSSV, Họ tên, Học bổng (>=7 được 1tr, ngược lại 0)
SELECT S.MSSV, S.Ten AS N'Họ tên',
    CASE 
        WHEN AVG(KQ.DiemKhoaHoc) >= 7 THEN 1000000 
        ELSE 0 
    END AS [Học bổng]
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten;

-- CAU: 49 - MSSV, họ tên, xếp loại theo điểm trung bình
-- NOTE: CASE xét từ TRÊN XUỐNG và dừng ở nhánh đúng đầu tiên → chỉ cần viết cận dưới giảm dần (>= 8 Giỏi,
--       >= 6.5 Khá, >= 5 Trung bình, còn lại Yếu). Mẫu: C0001F Khá, T0003M Trung bình, T0005M Giỏi, C0002M
--       Trung bình.
-- 49. Tạo dữ liệu 3 cột MSSV, Họ tên, Xếp loại căn cứ trên điểm trung bình.
SELECT S.MSSV, S.Ten AS N'Họ tên',
    CASE 
        WHEN AVG(KQ.DiemKhoaHoc) >= 8.0 THEN N'Giỏi'
        WHEN AVG(KQ.DiemKhoaHoc) >= 6.5 THEN N'Khá'
        WHEN AVG(KQ.DiemKhoaHoc) >= 5.0 THEN N'Trung bình'
        ELSE N'Yếu'
    END AS [Xếp loại]
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten

GO

-- ================================================================================================
-- SECTION: 6. SUB-QUERY - MAX / MIN - NHIỀU CÁCH VIẾT CHO MỘT ĐỀ (câu 51 → 57)
-- ================================================================================================
-- NOTE: Mỗi câu viết nhiều cách: (1) sub-query với MIN/MAX, (2) toán tử ALL, (3) TOP 1 WITH TIES, (4) hàm
--       xếp hạng RANK(). Các cách phải cho cùng kết quả.
-- CAU: 51 - Tên khoa có số lượng CBGD ít nhất
-- NOTE: Kết quả mẫu: Sinh học (SL_CBGD = 0).
-- 51.		Cho biết tên của khoa có số lượng CBGD ít nhất.

-- CACH: C1 - SL_CBGD = (SELECT MIN(SL_CBGD) ...): so với giá trị nhỏ nhất.
--Cach 1: Dung Min
SELECT TenKhoa
FROM Khoa
WHERE SL_CBGD = (SELECT MIN(SL_CBGD)
                 FROM Khoa
                )

-- CACH: C2 - SL_CBGD <= ALL (SELECT ...): nhỏ hơn hoặc bằng MỌI giá trị trong danh sách (ALL phải đúng với
--       từng dòng).
--Cach 2: Dung ALL
SELECT TenKhoa
FROM Khoa
WHERE SL_CBGD <= ALL (SELECT SL_CBGD
                      FROM Khoa
                     )

-- CACH: C3 - TOP 1 WITH TIES + ORDER BY tăng dần: dòng nhỏ nhất và các dòng đồng giá trị.
--Cach 3: Dung TOP TIES
SELECT TOP 1 WITH TIES TenKhoa, SL_CBGD
FROM KHOA
ORDER BY SL_CBGD
GO

-- CAU: 52 - SV có điểm tổng kết cao nhất trong khóa học 'K001'
-- NOTE: Chỉ có 2 SV ở K001 (C0001F 6.4, C0002M 5.8) → Bùi Thúy An. Cách 1: TOP 1 WITH TIES sau khi lọc
--       K001.
-- 52. Cho biết mã, tên, địa chỉ của các SV có DiemKhoaHoc lớn nhất trong khóa học có mã là ‘K001’.
SELECT TOP 1 WITH TIES S.MSSV, S.Ten AS N'Tên Sinh Viên', S.DiaChi
FROM SINHVIEN S
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE KQ.MaKhoaHoc = 'K001'
ORDER BY KQ.DiemKhoaHoc DESC;

-- CACH: c2 - điểm = (SELECT MAX(...) WHERE MaKhoaHoc = 'K001'): sub-query cũng phải lọc cùng khóa K001.
--c2
SELECT S.MSSV, S.Ten AS N'Tên Sinh Viên', S.DiaChi
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE KQ.MaKhoaHoc = 'K001' 
  AND KQ.DiemKhoaHoc = (
      SELECT MAX(DiemKhoaHoc) 
      FROM KETQUA 
      WHERE MaKhoaHoc = 'K001'
  );
GO

-- CAU: 53 - SV có điểm cao nhất trong môn 'Kỹ thuật lập trình'
-- NOTE: Môn KTLT chỉ có khóa K002: C0001F 7.8, T0003M 4.4 → Bùi Thúy An.
-- NOTE: C1/C2: sub-query bên trong có điều kiện M.TenMH = MH.TenMH tham chiếu bảng của truy vấn NGOÀI
--       (sub-query tương quan - correlated) nên được tính lại cho từng môn. Trong sub-query vẫn JOIN
--       SinhVien dù không cần.
-- 53. Tên các sinh viên có DiemKhoaHoc cao nhất trong môn 'Kỹ Thuật Lập Trình'.   

-- CACH: C1 - điểm = (SELECT MAX ...) tương quan theo tên môn.
--Cach 1: Dung MAX
SELECT SV.Ten
FROM KetQua KQ
JOIN SinhVien SV ON SV.MSSV = KQ.MSSV
JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
JOIN MonHoc MH ON GD.MaMH = MH.MaMH
WHERE MH.TenMH LIKE N'%Kỹ thuật lập trình%' AND KQ.DiemKhoaHoc = (SELECT MAX(KQ.DiemKhoaHoc)
                                                                  FROM KetQua KQ
                                                                  JOIN SinhVien SV ON SV.MSSV = KQ.MSSV
                                                                  JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
                                                                  JOIN MonHoc M ON GD.MaMH = M.MaMH
                                                                  WHERE M.TenMH = MH.TenMH
                                                                 )

-- CACH: C2 - điểm >= ALL (SELECT ... cùng môn): lớn hơn hoặc bằng mọi điểm của môn đó.
--Cach 2: Dung ALL
SELECT SV.Ten
FROM KetQua KQ
JOIN SinhVien SV ON SV.MSSV = KQ.MSSV
JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
JOIN MonHoc MH ON GD.MaMH = MH.MaMH
WHERE MH.TenMH LIKE N'%Kỹ thuật lập trình%' AND KQ.DiemKhoaHoc >= ALL (SELECT KQ.DiemKhoaHoc
                                                                       FROM KetQua KQ
                                                                       JOIN SinhVien SV ON SV.MSSV = KQ.MSSV
                                                                       JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
                                                                       JOIN MonHoc M ON GD.MaMH = M.MaMH
                                                                       WHERE M.TenMH = MH.TenMH
                                                                      )

-- CACH: C3 - TOP 1 WITH TIES + ORDER BY điểm giảm dần: gọn nhất. LIKE N'%Kỹ thuật lập trình' (không có %
--       cuối) vẫn khớp vì tên môn kết thúc đúng như vậy.
--Cach 3: Dung TOP TIES
SELECT TOP 1 WITH TIES SV.Ten, KQ.DiemKhoaHoc
FROM KetQua KQ
JOIN SinhVien SV ON SV.MSSV = KQ.MSSV
JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
JOIN MonHoc MH ON GD.MaMH = MH.MaMH
WHERE MH.TenMH LIKE N'%Kỹ thuật lập trình'
ORDER BY KQ.DiemKhoaHoc DESC
GO

-- CAU: 54 - Giáo viên tham gia giảng dạy nhiều khóa học nhất
-- NOTE: Kết quả mẫu: Hoàng Vương (C04M, 6 khóa). Có 4 cách, mỗi cách đều xử lý được trường hợp đồng hạng
--       nhất.
-- 54. Cho biết tên những giáo viên tham gia giảng dạy nhiều khóa học nhất.

-- CACH: C1 - TOP 1 WITH TIES + ORDER BY COUNT(...) DESC (ORDER BY được phép dùng hàm tổng hợp).
-- C1
SELECT TOP 1 WITH TIES GV.TenGV
FROM GIAOVIEN GV
JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
GROUP BY GV.MaGV, GV.TenGV
ORDER BY COUNT(GD.MaKhoaHoc) DESC

-- CACH: C2 - HAVING COUNT(...) >= ALL (SELECT COUNT(...) ... GROUP BY MaGV): số khóa của GV >= số khóa của
--       mọi GV.
-- C2
SELECT GV.TenGV
FROM GIAOVIEN GV
JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
GROUP BY GV.MaGV, GV.TenGV
HAVING COUNT(GD.MaKhoaHoc) >= ALL (
    SELECT COUNT(MaKhoaHoc) 
    FROM GIANGDAY 
    GROUP BY MaGV
)

-- CACH: C3 - HAVING COUNT(...) = (SELECT MAX(SoKhoaHoc) FROM (bảng dẫn xuất đếm khóa mỗi GV) T): lấy MAX
--       của các số đếm.
-- C3
SELECT GV.TenGV
FROM GIAOVIEN GV
JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
GROUP BY GV.MaGV, GV.TenGV
HAVING COUNT(GD.MaKhoaHoc) = (
    SELECT MAX(SoKhoaHoc) 
    FROM (
        SELECT COUNT(MaKhoaHoc) AS SoKhoaHoc 
        FROM GIANGDAY 
        GROUP BY MaGV
    ) T
)

-- CACH: c4 - RANK() OVER (ORDER BY COUNT(...) DESC) AS XepHang trong bảng dẫn xuất, rồi lọc XepHang = 1
--       (đồng hạng nhất đều ra).
-- c4
SELECT TenGV 
FROM (
    SELECT GV.TenGV, RANK() OVER(ORDER BY COUNT(GD.MaKhoaHoc) DESC) AS XepHang
    FROM GIAOVIEN GV
    JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
    GROUP BY GV.MaGV, GV.TenGV
) BangXepHang
WHERE XepHang = 1

GO

-- CAU: 55 - Mã số, tên và điểm tổng kết cao nhất của từng SV
-- NOTE: Kết quả mẫu: C0001F 8.6, T0003M 7.8, T0005M 8.8, C0002M 5.8 (SV chưa có điểm không hiện).
-- 55. Cho biết mã số, tên và DiemKhoaHoc cao nhất của từng SV.

-- CACH: C1 - GROUP BY MSSV, Ten + MAX(...): cách chuẩn và nhanh nhất.
-- C1
SELECT S.MSSV, S.Ten AS N'Tên Sinh Viên', MAX(KQ.DiemKhoaHoc) AS N'Điểm Cao Nhất'
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten

-- CACH: C2 - sub-query tương quan ngay trong SELECT (mỗi SV tự tính MAX) + EXISTS để loại SV chưa có điểm.
-- C2
SELECT S.MSSV, S.Ten AS N'Tên Sinh Viên', 
       (SELECT MAX(DiemKhoaHoc) FROM KETQUA WHERE MSSV = S.MSSV) AS N'Điểm Cao Nhất'
FROM SINHVIEN S
WHERE EXISTS (SELECT 1 FROM KETQUA WHERE MSSV = S.MSSV) 

-- CACH: C3 - MAX(...) OVER (PARTITION BY MSSV): hàm cửa sổ KHÔNG gộp dòng (mỗi dòng điểm vẫn ra 1 dòng) nên
--       phải thêm DISTINCT để gộp lại.
-- C3
SELECT DISTINCT S.MSSV, S.Ten AS N'Tên Sinh Viên', 
       MAX(KQ.DiemKhoaHoc) OVER(PARTITION BY S.MSSV) AS N'Điểm Cao Nhất'
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV

-- CAU: 56 - Với từng môn học: tên môn và điểm tổng kết cao nhất của môn đó
-- NOTE: Môn LTDT chưa có SV nào có điểm nên không xuất hiện ở cả 2 cách (vì JOIN / EXISTS đều đòi phải có
--       kết quả).
-- 56. Đối với từng môn học, cho biết tên môn học và DiemKhoaHoc cao nhất của môn học đó. 

-- CACH: C1 - JOIN MONHOC - GIANGDAY - KETQUA, GROUP BY MaMH, TenMH + MAX.
-- C1
SELECT MH.TenMH, MAX(KQ.DiemKhoaHoc) AS N'Điểm Cao Nhất'
FROM MONHOC MH
JOIN GIANGDAY GD ON MH.MaMH = GD.MaMH
JOIN KETQUA KQ ON GD.MaKhoaHoc = KQ.MaKhoaHoc
GROUP BY MH.MaMH, MH.TenMH

-- CACH: C2 - sub-query tương quan trong SELECT (theo MH.MaMH) + EXISTS để chỉ giữ môn có điểm.
-- C2
SELECT MH.TenMH, 
       (SELECT MAX(KQ.DiemKhoaHoc) 
        FROM KETQUA KQ 
        JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc 
        WHERE GD.MaMH = MH.MaMH) AS N'Điểm Cao Nhất'
FROM MONHOC MH
WHERE EXISTS (
    SELECT 1 
    FROM KETQUA KQ 
    JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc 
    WHERE GD.MaMH = MH.MaMH
)

-- CAU: 57 - Học kỳ nào có nhiều môn học được giảng dạy nhất (bỏ qua năm)
-- NOTE: COUNT(DISTINCT MaMH) theo HocKy: học kỳ 1 có 5 môn (CSDL, CTDL, CWIN, TRR, LTDT), học kỳ 2 có 1 môn
--       (KTLT) → học kỳ 1.
-- 57. Học kỳ nào có nhiều môn học được giảng dạy nhất (không quan tâm đến năm học).

-- CACH: C1 - TOP 1 WITH TIES + ORDER BY COUNT(DISTINCT ...) DESC.
-- C1
SELECT TOP 1 WITH TIES HocKy
FROM GIANGDAY
GROUP BY HocKy
ORDER BY COUNT(DISTINCT MaMH) DESC;

-- CACH: C2 - HAVING COUNT(DISTINCT ...) >= ALL (SELECT COUNT(DISTINCT ...) ... GROUP BY HocKy).
-- C2
SELECT HocKy
FROM GIANGDAY
GROUP BY HocKy
HAVING COUNT(DISTINCT MaMH) >= ALL (
    SELECT COUNT(DISTINCT MaMH) 
    FROM GIANGDAY 
    GROUP BY HocKy
)

-- FIXME: C3 thiếu BÍ DANH cho bảng dẫn xuất ")" và thiếu WHERE XepHang = 1 → lỗi cú pháp. Sửa: ) AS BXH
--        WHERE XepHang = 1 (và SELECT HocKy FROM BXH).
-- CACH: C3 - RANK() OVER (ORDER BY COUNT(DISTINCT MaMH) DESC) trong bảng dẫn xuất, rồi lấy hạng 1.
-- C3
SELECT HocKy
FROM (
    SELECT HocKy, RANK() OVER(ORDER BY COUNT(DISTINCT MaMH) DESC) AS XepHang
    FROM GIANGDAY
    GROUP BY HocKy
)
GO

-- ================================================================================================
-- SECTION: 7. LEFT JOIN + IIF / ISNULL - XỬ LÝ NULL (câu 66 → 73)
-- ================================================================================================
-- NOTE: LEFT JOIN giữ mọi dòng của bảng bên trái, phần không khớp bên phải = NULL. IIF(điều kiện, a, b) =
--       CASE WHEN điều kiện THEN a ELSE b END; ISNULL(x, y) thay NULL bằng y. Hai cách cho kết quả như
--       nhau, ISNULL gọn hơn.
-- CAU: 66 - Tên SV, điểm TB, số khóa đã học; SV chưa thi hiện thông báo
-- NOTE: Chuỗi AVG → ROUND 2 số lẻ → CAST DECIMAL(4,2) (đúng 2 chữ số thập phân) → CAST NVARCHAR(50): một
--       cột không thể vừa là số vừa là chữ nên phải đổi điểm sang chuỗi cho cùng kiểu với câu thông báo.
--       Hoàng Thị Hoa → 'SV chưa thi bất kỳ môn học nào', 0 khóa.
-- 66. Cho biết tên tất cả các sinh viên, điểm trung bình (của tất cả các DiemKhoaHoc), số lượng khóa học đã tham gia học tập. Với yêu cầu:
-- Nếu điểm trung bình có giá trị là NULL thì chuyển thành thông báo 'SV chưa thi bất kỳ môn học nào'.
-- Giá trị của điểm trung bình được định dạng với 2 số lẻ.

-- CACH: Lần 1 - IIF(AVG(...) IS NULL, thông báo, điểm đã định dạng).
-- Lần 1: Dùng IIF
SELECT SV.Ten, IIF(
                    AVG(KQ.DiemKhoaHoc) IS NULL, 
                    N'SV chưa thi bất kỳ môn học nào', 
                    CAST(CAST(ROUND(AVG(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50))
                  ) AS DiemTrungBinh, COUNT(KQ.MaKhoaHoc) AS SLKhoaHoc
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
GROUP BY SV.MSSV, SV.Ten;

-- CACH: Lần 2 - ISNULL(điểm đã định dạng, thông báo). COUNT(KQ.DiemKhoaHoc) khác COUNT(KQ.MaKhoaHoc) khi có
--       dòng điểm NULL; với dữ liệu hiện tại hai cách đếm giống nhau.
--Lần 2: Dùng ISNULL
SELECT SV.Ten, ISNULL(
                       CAST(CAST(ROUND(AVG(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50)),
                       N'SV chưa thi bất kỳ môn học nào'
                     ) AS DiemTrungBinh, COUNT(KQ.DiemKhoaHoc) AS SLKhoaHoc
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
GROUP BY SV.MSSV, SV.Ten

GO

-- CAU: 67 - Số tín chỉ mà từng SV đã tham gia (kể cả SV chưa học)
-- NOTE: Hai LEFT JOIN liên tiếp (SINHVIEN → KETQUA → GIANGDAY) để SV chưa học vẫn còn dòng; SUM(...) = NULL
--       thì đổi thành 0 (IIF hoặc ISNULL). Mẫu: C0001F 16, T0003M 12, T0005M 6, C0002M 4, C0004F 0.
-- 67. Cho biết số lượng tín chỉ mà từng sinh viên đã tham gia (gồm MSSV, tên SV, số lượng tín chỉ).
-- Lần 1: Dùng IIF
SELECT SV.MSSV, SV.Ten, IIF (
                              SUM(GD.TongSoTC) IS NULL,0,
                              SUM(GD.TongSoTC)
                            ) AS TongSoTinChi
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
LEFT JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
GROUP BY SV.MSSV, SV.Ten

-- Lần 2: Dùng ISNULL
SELECT SV.MSSV, SV.Ten, ISNULL(SUM(GD.TongSoTC), 0) AS TongSoTinChi
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
LEFT JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
GROUP BY SV.MSSV, SV.Ten;

GO

-- CAU: 68 - Tên môn, số SV có điểm, điểm nhỏ nhất của môn (môn chưa có điểm hiện thông báo)
-- NOTE: LEFT JOIN từ MONHOC qua GIANGDAY, KETQUA để môn chưa có điểm (LTDT) vẫn hiện: COUNT(KQ.DiemKhoaHoc)
--       = 0 và MIN(...) = NULL → 'Chưa có SV có điểm môn học này'.
-- BUG: Cột đặt tên DiemTrungBinh nhưng giá trị thực tế là MIN (điểm nhỏ nhất) - nên đổi bí danh thành
--      DiemNhoNhat.
-- 68. Cho biết tên tất cả các môn học, SL SV đã có điểm của môn học đó, DiemKhoaHoc nhỏ nhất của môn học đó. Nếu môn học nào chưa có SV có điểm thi thì in ra 'Chưa có SV có điểm môn học này'.
-- Lần 1: Dùng IIF
SELECT MH.TenMH, COUNT(KQ.DiemKhoaHoc) AS SLSV, IIF(
                                                      MIN(KQ.DiemKhoaHoc) IS NULL,
                                                      N'Chưa có SV có điểm môn học này',
                                                      CAST(CAST(ROUND(MIN(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50))
                                                   ) AS DiemTrungBinh
FROM MonHoc MH
LEFT JOIN GiangDay GD ON MH.MaMH = GD.MaMH
LEFT JOIN KetQua KQ ON GD.MaKhoaHoc = KQ.MaKhoaHoc
GROUP BY MH.MaMH, MH.TenMH

--Lần 2: Dùng ISNULL
SELECT MH.TenMH, COUNT(KQ.DiemKhoaHoc) AS SLSV, ISNULL(
                                                              CAST(CAST(ROUND(MIN(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50)),
                                                              N'Chưa có SV có điểm môn học này'
                                                            ) AS DiemTrungBinh
FROM MonHoc MH
LEFT JOIN GiangDay GD ON MH.MaMH = GD.MaMH
LEFT JOIN KetQua KQ ON GD.MaKhoaHoc = KQ.MaKhoaHoc
GROUP BY MH.MaMH, MH.TenMH

GO

-- CAU: 69 - Tên khoa + số SV của từng khoa (hiện TẤT CẢ khoa)
-- NOTE: LEFT JOIN từ KHOA + COUNT(sv.MSSV). Không dùng COUNT(*) vì COUNT(*) đếm cả dòng NULL thành 1 - SINH
--       phải ra 0, COUNT(sv.MSSV) bỏ qua NULL nên đúng.
-- 69. Cho biết tên khoa, số lượng sinh viên có trong từng khoa (tương tự câu 38, nhưng xuất kết quả cho tất cả các khoa).
SELECT k.TenKhoa,COUNT(sv.MSSV) AS [SL SV]
FROM Khoa k
LEFT JOIN SinhVien sv ON k.MaKhoa = sv.MaKhoa
GROUP BY k.MaKhoa, k.TenKhoa

GO

-- CAU: 70 - Tên khoa + số khóa học GV của khoa có dạy (hiện TẤT CẢ khoa)
-- NOTE: LEFT JOIN 2 lần (KHOA → GIAOVIEN → GIANGDAY) + COUNT(DISTINCT MaKhoaHoc). Mẫu: CNTT 8, TOAN 1, SINH
--       0.
-- 70. Cho biết tên khoa, số lượng khóa học mà giáo viên của khoa có tham gia giảng dạy (tương tự câu 39, nhưng xuất kết quả cho tất cả các khoa).
SELECT TenKhoa, COUNT(DISTINCT MaKhoaHoc) AS SLKhoaHoc
FROM Khoa K
LEFT JOIN GiaoVien GV ON K.MaKhoa = GV.MaKhoa
LEFT JOIN GiangDay GD ON GV.MaGV = GD.MaGV
GROUP BY TenKhoa

-- CAU: 71 (*) - Số điểm >= 8 của từng SV (hiện TẤT CẢ SV)
-- NOTE: Cách đang dùng: LEFT JOIN + SUM(IIF(điểm >= 8, 1, 0)): mỗi dòng điểm >= 8 tính 1, còn lại tính 0,
--       rồi cộng. Mẫu: C0001F 2, T0005M 1, các SV khác 0.
-- NOTE: ISNULL(..., 0) bên ngoài thực ra thừa vì SUM(IIF(...)) đã trả 0 (kể cả khi phía KETQUA là NULL).
-- TODO: Đề yêu cầu 2 cách, mới có 1. Gợi ý cách 2: LEFT JOIN KETQUA KQ ON SV.MSSV = KQ.MSSV AND
--       KQ.DiemKhoaHoc >= 8 (điều kiện đặt trong ON, KHÔNG đặt trong WHERE) rồi COUNT(KQ.MaKhoaHoc).
-- 71. (*) Cho biết số lượng DiemKhoaHoc >= 8 của từng sinh viên (tương tự câu 37, nhưng xuất kết quả cho tất cả các sinh viên có trong table SinhVien). SV có thể viết câu này bằng 2 cách khác nhau.
SELECT SV.MSSV, SV.Ten, ISNULL(SUM(IIF(KQ.DiemKhoaHoc >= 8, 1, 0)), 0) AS SLDiemKhoaHoc
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
GROUP BY SV.MSSV, SV.Ten
GO

-- CAU: 72 - Môn học chưa được tổ chức khóa học nào (anti-join, 3 cách)
-- NOTE: Kết quả mẫu: RỖNG vì cả 6 môn đều đã có khóa trong GIANGDAY.
-- CACH: Cách 1 EXCEPT: (tập MaMH của MONHOC) trừ (tập MaMH của GIANGDAY) = phép hiệu, rồi lấy tên môn.
-- CACH: Cách 2 NOT IN: bắt buộc có WHERE MaMH IS NOT NULL trong sub-query, vì chỉ cần 1 NULL thì NOT IN
--       không trả dòng nào.
-- CACH: Cách 3 LEFT JOIN ... WHERE GD.MaMH IS NULL: giữ lại các môn không khớp được khóa nào.
-- 72. Cho biết tên những môn học chưa được tổ chức cho các khóa học.
-- Cách 1: Dùng EXCEPT
SELECT TenMH 
FROM MonHoc 
WHERE MaMH IN (
                SELECT MaMH FROM MonHoc
                EXCEPT
                SELECT MaMH FROM GiangDay
              )

-- Cách 2: Dùng NOT IN
SELECT TenMH
FROM MonHoc
WHERE MaMH NOT IN (
                    SELECT MaMH 
                    FROM GiangDay 
                    WHERE MaMH IS NOT NULL
                  )

-- Cách 3: Dùng LEFT JOIN
SELECT MH.TenMH
FROM MonHoc MH
LEFT JOIN GiangDay GD ON MH.MaMH = GD.MaMH
WHERE GD.MaMH IS NULL

-- CAU: 73 - SV chưa có bất kỳ điểm nào trong KETQUA (anti-join, 3 cách)
-- NOTE: Kết quả mẫu: Hoàng Thị Hoa. Cùng khuôn với câu 72: NOT IN (có IS NOT NULL), LEFT JOIN ... IS NULL,
--       EXCEPT.
-- 73. Cho biết tên những sinh viên chưa có bất kỳ điểm nào trong table KetQua.
-- Cách 1: Dùng NOT IN
SELECT Ten
FROM SinhVien SV
WHERE MSSV NOT IN (
                    SELECT MSSV
                    FROM KetQua
                    WHERE MSSV IS NOT NULL
                  )

-- Cách 2: Dùng LEFT JOIN
SELECT SV.Ten 
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
WHERE KQ.MSSV IS NULL

-- Cách 3 Dùng EXCEPT
SELECT Ten
FROM SinhVien 
WHERE MSSV IN (
                SELECT MSSV FROM SinhVien
                EXCEPT
                SELECT MSSV FROM KetQua
              )

-- ================================================================================================
-- SECTION: 8. PHÉP CHIA - "TẤT CẢ" BẰNG NOT EXISTS LỒNG NHAU (câu 82 → 86)
-- ================================================================================================
-- NOTE: Mẫu "X làm đủ mọi Y" = KHÔNG TỒN TẠI Y nào mà X chưa làm: NOT EXISTS (Y ... NOT EXISTS (X đã làm
--       Y)). Lớp ngoài duyệt X, lớp giữa duyệt Y, lớp trong kiểm tra X đã làm Y chưa.
-- CAU: 82 - Giáo viên tham gia dạy đủ TẤT CẢ các môn học
-- NOTE: Kết quả mẫu: RỖNG (không GV nào dạy đủ 6 môn).
-- 82. Cho biết tên những giáo viên tham gia dạy đủ tất cả các môn học.
SELECT GV.TenGV
FROM GiaoVien GV
WHERE NOT EXISTS (
                  SELECT 1 
                  FROM MonHoc MH
                  WHERE NOT EXISTS (
                                     SELECT 1 
                                     FROM GiangDay GD 
                                     WHERE GD.MaGV = GV.MaGV AND GD.MaMH = MH.MaMH
                                    )
                )

-- CAU: 83 - Môn học mà TẤT CẢ giáo viên đều dạy
-- NOTE: Đảo vai trò của câu 82: ngoài là MONHOC, giữa là GIAOVIEN. Kết quả mẫu: RỖNG.
-- 83. Cho biết tên những môn học mà tất cả các giáo viên đều tham gia giảng dạy.
SELECT MH.TenMH
FROM MonHoc MH
WHERE NOT EXISTS (
                  SELECT 1 
                  FROM GiaoVien GV
                  WHERE NOT EXISTS (
                                     SELECT 1 
                                     FROM GiangDay GD 
                                     WHERE GD.MaMH = MH.MaMH AND GD.MaGV = GV.MaGV
                                   )
                 )

-- CAU: 84 - Khóa học mà TẤT CẢ sinh viên đều tham gia
-- NOTE: Ngoài: GIANGDAY, giữa: SINHVIEN, trong: tồn tại dòng KETQUA (SV, khóa). Kết quả mẫu: RỖNG.
-- 84. Cho biết khóa học mà tất cả các sinh viên đều tham gia.
SELECT GD.MaKhoaHoc
FROM GiangDay GD
WHERE NOT EXISTS (SELECT 1 
                  FROM SinhVien SV
                  WHERE NOT EXISTS (SELECT 1 
                                    FROM KetQua KQ
                                    WHERE KQ.MaKhoaHoc = GD.MaKhoaHoc AND KQ.MSSV = SV.MSSV)
);

-- CAU: 85 - Sinh viên tham gia đủ TẤT CẢ các khóa học
-- NOTE: Đảo vai trò của câu 84. Kết quả mẫu: RỖNG.
-- 85. Cho biết tên những sinh viên tham gia đủ tất cả các khóa học.
SELECT SV.Ten
FROM SinhVien SV
WHERE NOT EXISTS (SELECT 1 
                  FROM GiangDay GD
                  WHERE NOT EXISTS (SELECT 1 
                                    FROM KetQua KQ
                                    WHERE KQ.MSSV = SV.MSSV AND KQ.MaKhoaHoc = GD.MaKhoaHoc
    )
);

-- CAU: 86 - Môn học mà TẤT CẢ sinh viên đều học
-- NOTE: Môn gắn với SV gián tiếp nên lớp trong phải JOIN KETQUA - GIANGDAY. Kết quả mẫu: RỖNG.
-- TODO: Cả 5 câu 82-86 đều cho kết quả rỗng với dữ liệu mẫu → muốn kiểm tra logic nên thêm dữ liệu thử (vd
--       1 GV dạy đủ mọi môn) rồi xóa đi.
-- 86. Cho biết tên môn học mà tất cả các sinh viên đều học.
SELECT MH.TenMH
FROM MonHoc MH
WHERE NOT EXISTS (SELECT 1 
                  FROM SinhVien SV
                  WHERE NOT EXISTS (SELECT 1 
                                    FROM KetQua KQ 
                                    JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
                                    WHERE GD.MaMH = MH.MaMH AND KQ.MSSV = SV.MSSV
    )
);

-- ================================================================================================
-- SECTION: 9. ALTER + UPDATE: THÊM CỘT THỐNG KÊ CHO SINHVIEN (câu 90 → 92)
-- ================================================================================================
-- NOTE: Cách làm "cột dự trữ" (denormalize): lưu SLMon, DTB, ... thẳng vào SINHVIEN → đọc nhanh nhưng KHÔNG
--       tự cập nhật khi KETQUA thay đổi; muốn đúng phải chạy lại các UPDATE.
-- CAU: 90 - Thêm 5 cột SLMon, DTB, DTBTichLuy, SoTCTichLuy, XL vào SINHVIEN
-- NOTE: ALTER TABLE ... ADD thêm cột (giá trị ban đầu là NULL); DROP COLUMN ngay phía trên dùng để chạy lại
--       script.
-- FIXME: ALTER TABLE ... DROP COLUMN SLMon, DTB, ... chạy LẦN ĐẦU sẽ lỗi vì các cột chưa tồn tại (Msg
--        4924). Muốn chạy lại an toàn dùng: DROP COLUMN IF EXISTS SLMon, DTB, DTBTichLuy, SoTCTichLuy, XL
--        (SQL Server 2016 trở lên).
-- NOTE: Cột XL (xếp loại) khai báo ở đây về sau KHÔNG được dùng; câu 91f lại tạo thêm cột XepLoai → có 2
--       cột trùng ý nghĩa.
-- TODO: Thống nhất dùng 1 cột xếp loại (XL hoặc XepLoai) và xóa cột còn lại.
--90.	Thêm các field SLMon(Số lượng môn), DTB (Điểm trung bình), DTBTichLuy (Điểm trung bình tích lũy), SoTCTichLuy(SoTCTichLuy), XL(Xếp loại) vào table SinhVien.
ALTER TABLE SINHVIEN 
DROP COLUMN SLMon, DTB, DTBTichLuy, SoTCTichLuy, XL;
ALTER TABLE SINHVIEN
ADD 
    SLMon INT, DTB FLOAT, DTBTichLuy FLOAT, SoTCTichLuy INT, XL NVARCHAR(20);

-- CAU: 91 - Cập nhật giá trị cho các cột vừa tạo (a → f)
-- FIXME: Thiếu GO sau lệnh ALTER ... ADD ở trên: các UPDATE phía dưới dùng cột mới (SLMon, DTB, ...) trong
--        CÙNG batch → SQL Server báo "Invalid column name" lúc biên dịch. Thêm GO ngay sau ALTER ... ADD
--        (câu 90) và sau ALTER ... ADD XepLoai (câu 91f).
--91.	Cập nhật thông tin cho các field vừa tạo theo yêu cầu:

-- CAU: 91a - NgayNhapHoc: CNTT = 15/11/2011, TOAN = 22/10/2011, khoa khác giữ nguyên
-- NOTE: UPDATE ... SET cột = CASE ... ELSE cột END: khoa khác nhận lại chính giá trị cũ nên "giữ nguyên".
--       Không có WHERE → quét mọi dòng. Các CHECK (đủ 18 tuổi...) được kiểm tra lại nhưng ngày mới vẫn hợp
--       lệ.
--a.-	NgayNhapHoc: sinh viên khoa CNTT nhập học ngày 15/11/2011; sinh viên khoa TOAN nhập học ngày 22/10/2011; các Khoa khác giữ nguyên giá trị ngày đang có.
UPDATE SINHVIEN
SET NgayNhapHoc = CASE 
    WHEN MaKhoa = 'CNTT' THEN '2011-11-15'
    WHEN MaKhoa = 'TOAN' THEN '2011-10-22'
    ELSE NgayNhapHoc
END

-- CAU: 91b - SLMon: số môn SV đã có điểm
-- NOTE: Sub-query tương quan: với mỗi SV (WHERE KETQUA.MSSV = SINHVIEN.MSSV) đếm số dòng KETQUA của chính
--       SV đó. SV chưa có điểm = 0.
--b.-	SLMon: tổng số lượng môn học mà sinh viên đã kiểm tra (có điểm).
UPDATE SINHVIEN
SET SLMon = (
    SELECT COUNT(*) 
    FROM KETQUA 
    WHERE KETQUA.MSSV = SINHVIEN.MSSV
)

-- CAU: 91c - DTB: điểm TB của mọi điểm đã có
-- FIXME: SUM(DiemKhoaHoc) / SLMon: SLMon lấy từ cột của SINHVIEN (phụ thuộc 91b đã chạy) và SV có SLMon = 0
--        (Hoàng Thị Hoa) → nguy cơ chia cho 0. Nên dùng AVG(DiemKhoaHoc): SV chưa có điểm sẽ ra NULL an
--        toàn.
--c.-	DTB: điểm trung bình của tất cả các điểm mà sinh viên đã có (kể cả những DiemKhoaHoc<5).
UPDATE SINHVIEN
SET DTB = (
    SELECT SUM(DiemKhoaHoc) / SLMon
    FROM KETQUA
    WHERE KETQUA.MSSV = SINHVIEN.MSSV
)

-- CAU: 91d - DTBTichLuy: điểm TB của các điểm >= 5, SV chưa có điểm = 0
-- NOTE: Đề yêu cầu đổi cột sang NVARCHAR(30): ALTER COLUMN chuyển FLOAT → chuỗi. UPDATE tính AVG chỉ trên
--       điểm >= 5, ISNULL(..., 0) → 0 nếu không có điểm nào đạt. Vd T0003M chỉ tính 7.8 (bỏ 3.9 và 4.4).
-- BUG: Vì có ISNULL nên DTBTichLuy KHÔNG BAO GIỜ NULL → nhánh "Chưa xếp loại" ở 91f không bao giờ chạy; SV
--      chưa học bị xếp "Yếu" (0 < 5).
-- BUG: DTBTichLuy giờ là CHUỖI: so sánh với số (câu 94) cần ép kiểu tường minh, xem cảnh báo ở câu 94.
--d.-	DTBTichLuy: 
--•	Thêm mới cột điểm trung bình DTBTichLuy với kiểu dữ liệu là nvarchar(30).
--•	Tính điểm trung bình của tất cả các DiemKhoaHoc>=5 của từng SV. Nếu SV chưa có bất kỳ điểm nào trong table KetQua thì DTBTichLuy sẽ nhận giá trị là 0.

ALTER TABLE SinhVien
ALTER COLUMN DTBTichLuy nvarchar(30);

UPDATE SinhVien
SET DTBTichLuy = (
    SELECT ISNULL(AVG(DiemKhoaHoc), 0)
    FROM KetQua
    WHERE KetQua.MSSV = SinhVien.MSSV
    AND DiemKhoaHoc >= 5
)

-- CAU: 91e - SoTCTichLuy: tổng tín chỉ của các khóa đạt (điểm >= 5), SV chưa học = 0
-- NOTE: JOIN KETQUA - GIANGDAY trong sub-query để lấy TongSoTC của những khóa có điểm >= 5, ISNULL(SUM, 0).
--       Mẫu: C0001F 16, T0003M 4 (chỉ K004), T0005M 6, C0002M 4, C0004F 0.
--e.-	SoTCTichLuy: tương tự câu trên, nhưng tính tổng số các tín chỉ của những DiemKhoaHoc >=5. Đối với sinh viên chưa học sẽ nhận giá trị 0.

UPDATE SinhVien
SET SoTCTichLuy = (
    SELECT ISNULL(SUM(GiangDay.TongSoTC), 0)
    FROM KetQua
    JOIN GiangDay
    ON KetQua.MaKhoaHoc = GiangDay.MaKhoaHoc
    WHERE KetQua.MSSV = SinhVien.MSSV
    AND DiemKhoaHoc >= 5
)

-- CAU: 91f - XepLoai theo DTBTichLuy (Yếu / Trung bình / Khá / Giỏi / Xuất sắc / Chưa xếp loại)
-- FIXME: ALTER TABLE ... ADD XepLoai và UPDATE ... SET XepLoai nằm CÙNG batch (không có GO ở giữa) → lỗi
--        "Invalid column name". Thêm GO.
-- NOTE: CASE xét từ trên xuống: < 5 Yếu, < 6.5 Trung bình, < 8 Khá, < 9 Giỏi, <= 10 Xuất sắc; ELSE "Không
--       hợp lệ" bắt giá trị ngoài 0-10.
-- TODO: DTBTichLuy là NVARCHAR nên so sánh với 5.0 dựa vào chuyển kiểu ngầm; an toàn hơn là CAST(DTBTichLuy
--       AS FLOAT) trong CASE.
--f.-	XepLoai:	nếu 	DTBTichLuy = NULL	: Chưa xếp loại 
		--DTBTichLuy <5.0		: yếu
--5.0 <= DTBTichLuy < 6.5	: trung bình
--6.5 <= DTBTichLuy < 8.0	: khá
--8.0 <= DTBTichLuy < 9.0	: giỏi
--9.0 <= DTBTichLuy <=10.0	: xuất sắc
ALTER TABLE SINHVIEN
ADD  XepLoai NVARCHAR(30)
UPDATE SINHVIEN
SET XepLoai = CASE 
    WHEN DTBTichLuy IS NULL THEN N'Chưa xếp loại'
    WHEN DTBTichLuy < 5.0 THEN N'Yếu'
    WHEN DTBTichLuy < 6.5 THEN N'Trung bình'
    WHEN DTBTichLuy < 8.0 THEN N'Khá'
    WHEN DTBTichLuy < 9.0 THEN N'Giỏi'
    WHEN DTBTichLuy <= 10.0 THEN N'Xuất sắc'
    ELSE N'Không hợp lệ'
END

-- CAU: 92 (bản 1) - Cột HocBong kiểu NVARCHAR theo DTBTichLuy: >= 9 → 2.000.000, 8..<9 → 1.000.000, < 8 → 0
-- NOTE: Có GO riêng sau ALTER ... ADD nên UPDATE phía dưới chạy được. CASE tuần tự: < 8 → "0 đ", < 9 →
--       "1.000.000đ", >= 9 → "2.000.000 đ".
-- BUG: Chuỗi học bổng không đồng nhất định dạng ('1.000.000đ' thiếu khoảng trắng, '2.000.000 đ' có) và dùng
--      chuỗi cho số tiền → khó tính toán; bản INT ở dưới tốt hơn.
-- FIXME: Câu 92 bị viết 2 lần: bản 2 lại ADD HocBong → lỗi "Column names in each table must be unique" (Msg
--        2705). Chỉ giữ 1 bản (nên giữ bản INT), hoặc DROP COLUMN HocBong trước khi ADD lại.
--92.	Thực hiện thêm mới cột Học bổng cho table SinhVien dựa trên cột DTBTichLuy với quy định 3 mức học bổng như sau:
	--DTBTichLuy >= 9	: 	2.000.000 đ
--8 <= 	DTBTichLuy <   9	:	1.000.000 đ
	--DTBTichLuy <   8	:	0 đ
ALTER TABLE SINHVIEN 
ADD HocBong NVARCHAR(30)
GO
UPDATE SINHVIEN
SET HocBong = CASE
    WHEN DTBTichLuy < 8.0 THEN N'0 đ'
    WHEN DTBTichLuy < 9.0 THEN N'1.000.000đ'
    WHEN DTBTichLuy >= 9.0 THEN N'2.000.000 đ'
    ELSE N'Không hợp lệ'
END

-- ================================================================================================
-- SECTION: 10. DELETE (câu 93 → 95)
-- ================================================================================================
-- CAU: 93 - Xóa mọi kết quả học tập của SV 'C0002M'
-- NOTE: DELETE FROM ... WHERE MSSV = ...; thiếu WHERE sẽ xóa TOÀN BỘ bảng. Phải xóa ở bảng con (KETQUA)
--       trước nếu sau đó muốn xóa SV (vướng khóa ngoại). Các cột SLMon / DTB... của C0002M trở nên cũ vì
--       không tự cập nhật.
--93.	Xóa tất cả kết quả học tập của sinh viên ‘C0002M’.
DELETE FROM KETQUA
WHERE MSSV = 'C0002M'

-- CAU: 94 - Xóa SV có DTBTichLuy < 5 hoặc chưa có điểm nào
-- FIXME: DTBTichLuy là NVARCHAR mà so với số nguyên 5: SQL Server ép CHUỖI sang INT (int có độ ưu tiên cao
--        hơn) và lỗi ngay khi gặp giá trị thập phân ("Conversion failed when converting the nvarchar value
--        '7.8' to data type int"). Sửa: WHERE CAST(DTBTichLuy AS FLOAT) < 5 OR DTBTichLuy IS NULL.
-- NOTE: SV còn dòng KETQUA sẽ bị chặn bởi khóa ngoại FK_KetQua_SinhVien. Vì UPDATE ở câu 91 chạy TRƯỚC khi
--       xóa kết quả C0002M (câu 93) nên C0002M vẫn có DTBTichLuy = 5.8 (không < 5) và không bị xóa; chỉ
--       Hoàng Thị Hoa (DTBTichLuy = 0) bị xóa.
--94.	Xóa tên những sinh viên có điểm trung bình (DTBTichLuy) dưới 5 hoặc chưa có bất kỳ điểm nào trong table KetQua.
DELETE FROM SINHVIEN
WHERE DTBTichLuy < 5 OR DTBTichLuy IS NULL

-- CAU: 95 - Xóa những khoa không có sinh viên theo học
-- NOTE: WHERE MaKhoa NOT IN (SELECT MaKhoa FROM SINHVIEN): nếu sub-query có NULL thì NOT IN không trả dòng
--       nào → không xóa gì (bản sau thêm IS NOT NULL để tránh). Mẫu: xóa khoa SINH (không SV, không GV nên
--       không vướng khóa ngoại). Dòng SELECT * FROM khoa bên dưới để kiểm tra.
--95.	Xóa những khoa không có sinh viên theo học.
DELETE KHOA
WHERE MaKhoa NOT IN (SELECT MaKhoa FROM SINHVIEN)

SELECT *  
FROM khoa

-- CAU: 92 (bản 2) - Cột HocBong kiểu INT (2000000 / 1000000 / 0)
-- NOTE: Số tiền lưu dạng số (INT) nên cộng/so sánh được - tốt hơn bản chuỗi. Vì DTBTichLuy là chuỗi nên
--       phải CAST(DTBTichLuy AS FLOAT); điều kiện DTBTichLuy <> '0' loại SV không có điểm đạt.
-- FIXME: ADD HocBong INT bị TRÙNG với cột HocBong đã tạo ở bản 1, và UPDATE nằm cùng batch với ALTER (thiếu
--        GO). Bỏ bản 1 (hoặc DROP COLUMN HocBong) và thêm GO.
-- 92.	Thực hiện thêm mới cột Học bổng cho table SinhVien dựa trên cột DTBTichLuy với quy định 3 mức học bổng như sau:
ALTER TABLE SinhVien
ADD HocBong INT

-- 	DTBTichLuy >= 9	: 	2.000.000 đ
-- 8 <= 	DTBTichLuy <   9	:	1.000.000 đ
-- 	DTBTichLuy <   8	:	0 đ
UPDATE SinhVien
SET HocBong = CASE
    WHEN DTBTichLuy IS NOT NULL AND DTBTichLuy <> '0' AND CAST(DTBTichLuy AS FLOAT) >= 9.0
        THEN 2000000
    WHEN DTBTichLuy IS NOT NULL AND DTBTichLuy <> '0' AND CAST(DTBTichLuy AS FLOAT) >= 8.0
        THEN 1000000
    ELSE 0
END

-- ================================================================================================
-- SECTION: 10b. DELETE - BẢN VIẾT LẠI (lặp lại câu 93 → 95)
-- ================================================================================================
-- NOTE: Phần này lặp lại 93-95 ở trên (viết gọn hơn; câu 95 đã thêm IS NOT NULL). Chạy lại không lỗi nhưng
--       không còn gì để xóa; nên xóa bản trùng.
-- 3.3.11.	Delete

-- CAU: 93 (bản 2) - Giống bản 1
-- NOTE: Chạy lại: không còn dòng KETQUA của C0002M nên xóa 0 dòng.
-- 93.	Xóa tất cả kết quả học tập của sinh viên ‘C0002M’.
DELETE 
FROM KetQua
WHERE MSSV = 'C0002M'

-- CAU: 94 (bản 2) - Giống bản 1
-- FIXME: Vẫn còn lỗi so sánh DTBTichLuy (chuỗi) với số nguyên 5 như bản 1 → dùng CAST(DTBTichLuy AS FLOAT)
--        < 5.
-- 94.	Xóa tên những sinh viên có điểm trung bình (DTBTichLuy) dưới 5 hoặc chưa có bất kỳ điểm nào trong table KetQua.
DELETE 
FROM SINHVIEN
WHERE DTBTichLuy < 5 OR DTBTichLuy IS NULL

-- CAU: 95 (bản 2) - Xóa khoa không có SV, an toàn với NULL
-- NOTE: Có WHERE MaKhoa IS NOT NULL trong sub-query để NOT IN không bị NULL làm hỏng kết quả.
-- 95.	Xóa những khoa không có sinh viên theo học.
DELETE 
FROM Khoa
WHERE MaKHoa NOT IN (
    SELECT MaKhoa
    FROM SinhVien
    WHERE MaKhoa IS NOT NULL
)

-- ================================================================================================
-- SECTION: 11. NHẬP DỮ LIỆU TỪ CSV QUA BẢNG PHỤ
-- ================================================================================================
-- NOTE: Quy trình: (1) import file CSV thành bảng phụ Khoa_tmp (Import Flat File của SSMS / Azure Data
--       Studio hoặc BULK INSERT) → (2) SELECT kiểm tra → (3) INSERT ... SELECT chỉ các khoa chưa có → (4)
--       DROP bảng phụ.
-- NOTE: INSERT INTO Khoa ... SELECT ... WHERE NOT EXISTS (SELECT 1 FROM Khoa k WHERE k.MaKhoa = t.MaKhoa):
--       bỏ qua dòng trùng khóa chính để không bị lỗi PRIMARY KEY.
-- FIXME: Bảng Khoa_tmp không được tạo trong file này → chạy thẳng sẽ báo "Invalid object name Khoa_tmp";
--        phải import CSV trước.
-- NOTE: Dữ liệu CSV vẫn phải thỏa CHECK của KHOA (SL_CBGD từ 0 đến 4), nếu không INSERT sẽ lỗi.
-- Thêm dữ liệu bằng file CSV làm bảng phụ rồi gép lại xong xoá bảng phụ 
SELECT * FROM Khoa_tmp;
SELECT * FROM Khoa;

INSERT INTO Khoa (MaKhoa, TenKhoa, SL_CBGD)
SELECT t.MaKhoa, t.TenKhoa, t.SL_CBGD
FROM Khoa_tmp t
WHERE NOT EXISTS (SELECT 1 FROM Khoa k WHERE k.MaKhoa = t.MaKhoa);

DROP TABLE Khoa_tmp;