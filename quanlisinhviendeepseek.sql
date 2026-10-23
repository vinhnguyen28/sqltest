-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P0] KHỞI TẠO DATABASE - DROP nếu tồn tại rồi CREATE mới
-- NOTE: USE master để đứng ở context có quyền DROP database
-- NOTE: DROP DATABASE sẽ xoá toàn bộ bảng + dữ liệu cũ
-- ═══════════════════════════════════════════════════════════════════════════
USE master;
GO
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'QuanLySinhVien')
    DROP DATABASE QuanLySinhVien;
GO
CREATE DATABASE QuanLySinhVien;
GO
USE QuanLySinhVien;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P1] TẠO BẢNG KHOA
-- NOTE: SL_CBGD (Số lượng cán bộ giảng dạy) giới hạn 0..4 → mỗi khoa tối đa 4 GV
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE KHOA (
    MaKhoa VARCHAR(10) PRIMARY KEY,
    TenKhoa NVARCHAR(100) NOT NULL,
    SL_CBGD INT DEFAULT 0 CHECK (SL_CBGD BETWEEN 0 AND 4)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P2] TẠO BẢNG MONHOC (Môn học)
-- NOTE: SoTC_ToiThieu >= 2 (mỗi môn tối thiểu 2 tín chỉ)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE MONHOC (
    MaMH VARCHAR(10) PRIMARY KEY,
    TenMH NVARCHAR(100) NOT NULL,
    SoTC_ToiThieu INT CHECK (SoTC_ToiThieu >= 2)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P3] TẠO BẢNG GIAOVIEN
-- NOTE: MaGV format: [A-Z][0-9][0-9][F|M]
--       Ví dụ: C01F (khoa C, số 01, Nữ), T02M (khoa T, số 02, Nam)
-- NOTE: FK MaKhoa → KHOA (quan hệ 1-N: 1 khoa có nhiều GV)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE GIAOVIEN (
    MaGV VARCHAR(4) PRIMARY KEY 
        CHECK (MaGV LIKE '[A-Z][0-9][0-9][FM]'),
    TenGV NVARCHAR(100) NOT NULL,
    MaKhoa VARCHAR(10),
    CONSTRAINT FK_GiaoVien_Khoa FOREIGN KEY (MaKhoa) REFERENCES KHOA(MaKhoa)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P4] TẠO BẢNG SINHVIEN (bảng trung tâm)
-- NOTE: MSSV format: [A-Z][0-9][0-9][0-9][0-9][F|M] → 6 ký tự
-- NOTE: PhaiNu: 0=Nam, 1=Nữ
-- NOTE: DienThoai: chỉ số, độ dài 8 hoặc 10
-- NOTE: CHECK tuổi >= 18 khi nhập học (DATEDIFF năm)
-- NOTE: CHECK vào Đoàn >= 16 tuổi, vào Đảng phải >= ngày vào Đoàn
-- FIXME: SoCMND UNIQUE nhưng nhiều dòng insert dùng số khác nhau OK, nhưng bảng KETQUA insert dùng MSSV 'C0002M' - hợp lệ
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P5] TẠO BẢNG GIANGDAY (Khóa học được mở)
-- NOTE: MaKhoaHoc format: K + 3 số (K001..K999)
-- NOTE: SoTietLT / SoTietTH là cột COMPUTED (tự tính):
--       Số tiết LT = Số TC LT * 15
--       Số tiết TH = Số TC TH * 30
-- NOTE: CHECK TongSoTC = SoTCLT + SoTCTH (tổng TC phải bằng LT+TH)
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P6] TẠO BẢNG KETQUA (Điểm của SV theo khóa học)
-- NOTE: PK phức hợp (MSSV, MaKhoaHoc) - mỗi SV chỉ có 1 điểm cho 1 khóa
-- NOTE: 3 cột điểm: Giữa kỳ, Thi lần 1, Thi lần 2 (default 0)
-- NOTE: DiemKhoaHoc là điểm tổng kết (có thể NULL nếu chưa thi)
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P7] THÊM CONSTRAINT LyDoNgungHoc (phải là 1 trong 6 giá trị cố định)
-- NOTE: Dùng ALTER vì lý do phải tách riêng - CHECK nhiều giá trị N'...'
-- ═══════════════════════════════════════════════════════════════════════════
GO
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [P8] INSERT DỮ LIỆU MẪU
-- NOTE: 3 khoa: CNTT (3 CBGD), TOAN (1), SINH (0)
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO KHOA (MaKhoa, TenKhoa, SL_CBGD) VALUES 
('CNTT', N'Công nghệ thông tin', 3),
('TOAN', N'Toán', 1),
('SINH', N'Sinh học', 0);
GO

-- NOTE: 5 sinh viên - C0001F, C0002M, T0003M, C0004F, T0005M
-- NOTE: C0001F đã ra trường 2012-11-15 với lý do 'xin thôi học'
-- NOTE: T0003M có NgayVaoDoan 2007-08-17, NgayVaoDang 2012-05-01
INSERT INTO SINHVIEN VALUES ('C0001F', N'Bùi Thúy An', 1, N'223 Trần Hưng Đạo, HCM', '38132202', 'CNTT', '135792468', '1992-08-14', '2010-10-01', NULL, NULL, '2012-11-15', N'xin thôi học');
INSERT INTO SINHVIEN VALUES ('C0002M', N'Nguyễn Thanh Tùng', 0, N'140 Công Quỳnh, Sóc Trăng', '38125678', 'CNTT', '987654321', '1992-11-23', '2010-11-23', NULL, NULL, NULL, NULL);
INSERT INTO SINHVIEN VALUES ('T0003M', N'Nguyễn Thành Long', 0, N'112/4 Công Quỳnh, HCM', '0918345623', 'TOAN', '123456789', '1991-08-17', '2010-10-01', '2007-08-17', '2012-05-01', NULL, NULL);
INSERT INTO SINHVIEN VALUES ('C0004F', N'Hoàng Thị Hoa', 1, N'90 Nguyễn Văn Cừ, HCM', '38320123', 'CNTT', '246813579', '1991-09-02', '2010-10-17', NULL, NULL, NULL, NULL);
INSERT INTO SINHVIEN VALUES ('T0005M', N'Trần Hồng Sơn', 0, N'54 Cao Thắng, Hà Nội', '38345987', 'TOAN', '864297531', '1993-04-24', '2011-10-15', '2010-09-02', NULL, NULL, NULL);
GO

-- NOTE: 5 giáo viên: C01F, T02M, C03M, C04M, T05F
USE QuanLySinhVien;
GO
INSERT INTO GIAOVIEN (MaGV, TenGV, MaKhoa) VALUES 
('C01F', N'Phạm Thị Thảo', 'CNTT'),
('T02M', N'Lâm Hoàng Vũ', 'TOAN'),
('C03M', N'Trần Văn Tiến', 'CNTT'),
('C04M', N'Hoàng Vương', 'CNTT'),
('T05F', N'Thanh Trà', 'TOAN');
GO

-- NOTE: 6 môn học: CSDL, CTDL, KTLT, CWIN, TRR, LTDT
INSERT INTO MONHOC (MaMH, TenMH, SoTC_ToiThieu) VALUES 
('CSDL', N'Cơ sở dữ liệu', 2),
('CTDL', N'Cấu trúc dữ liệu', 3),
('KTLT', N'Kỹ thuật lập trình', 3),
('CWIN', N'Lập trình C trên Windows', 3),
('TRR', N'Toán rời rạc', 2),
('LTDT', N'Lý thuyết đồ thị', 2);
GO

-- NOTE: 9 khóa học K001..K009
-- NOTE: SoTietLT = SoTCLT*15, SoTietTH = SoTCTH*30 (computed)
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

-- NOTE: 10 dòng kết quả - mỗi dòng là 1 SV học 1 khóa học
-- NOTE: DiemThiLan2 NULL = không phải thi lại
-- NOTE: DiemKhoaHoc thường = 0.4*GiữaKỳ + 0.6*max(Thi1, Thi2)
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


-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q1] Liệt kê Tên, Địa chỉ, Điện thoại tất cả SV
-- NOTE: SELECT 3 cột từ bảng SINHVIEN, không lọc → tất cả dòng
-- ═══════════════════════════════════════════════════════════════════════════
SELECT Ten, DiaChi, DienThoai 
FROM SINHVIEN;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q2] Tên môn học + số tín chỉ tối thiểu
-- NOTE: SELECT 2 cột từ MONHOC
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenMH, SoTC_ToiThieu 
FROM MONHOC;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q3] Kết quả học tập của SV có MSSV='T0003M'
-- NOTE: WHERE MSSV = 'T0003M' → lấy tất cả dòng KETQUA của SV này
-- ═══════════════════════════════════════════════════════════════════════════
SELECT * 
FROM KETQUA 
WHERE MSSV = 'T0003M';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q4] GV có ký tự thứ 3 của TenGV là 'A' hoặc 'a'
-- NOTE: LIKE '__A%' → 2 ký tự đầu bất kỳ, ký tự thứ 3 = 'A'
-- NOTE: OR LIKE '__a%' để bắt cả chữ thường
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenGV 
FROM GIAOVIEN 
WHERE TenGV LIKE '__A%' OR TenGV LIKE '__a%';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q5] Môn học có chứa chữ 'dữ'
-- NOTE: LIKE N'%dữ%' - N prefix cho Unicode tiếng Việt
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenMH 
FROM MONHOC 
WHERE TenMH LIKE N'%dữ%';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q6] GV có tên bắt đầu bằng 'P' hoặc 'L'
-- NOTE: LIKE 'P%' (P + bất kỳ) OR LIKE 'L%'
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenGV 
FROM GIAOVIEN 
WHERE TenGV LIKE 'P%' OR TenGV LIKE 'L%';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q7] SV có địa chỉ trên đường 'Cống Quỳnh' (thực tế data là 'Công Quỳnh')
-- NOTE: LIKE N'%Công Quỳnh%' - lọc theo chuỗi con
-- BUG: Đề bài ghi 'Cống Quỳnh' nhưng data lại là 'Công Quỳnh' - query dùng 'Công' nên match đúng
-- ═══════════════════════════════════════════════════════════════════════════
SELECT Ten, DiaChi 
FROM SINHVIEN 
WHERE DiaChi LIKE N'%Công Quỳnh%';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q8] Môn có MaMH pattern: ký tự 1='C', ký tự 3='D' + thông tin khóa học
-- NOTE: LIKE 'C_D%' → C, bất kỳ, D, phần còn lại
-- NOTE: JOIN MONHOC ↔ GIANGDAY qua MaMH
-- ═══════════════════════════════════════════════════════════════════════════
SELECT m.MaMH, m.TenMH, g.MaKhoaHoc, g.TongSoTC 
FROM MONHOC m
JOIN GIANGDAY g ON m.MaMH = g.MaMH
WHERE m.MaMH LIKE 'C_D%';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q9] Môn học được dạy trong niên khóa '2011-2012'
-- NOTE: DISTINCT để loại trùng (1 môn có thể mở nhiều khóa)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT m.TenMH 
FROM MONHOC m
JOIN GIANGDAY g ON m.MaMH = g.MaMH
WHERE g.NienKhoa = '2011-2012';

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q10] Tên khoa, MSSV, tên, địa chỉ SV - sắp xếp A-Z theo tên
-- NOTE: INNER JOIN KHOA ↔ SINHVIEN qua MaKhoa
-- NOTE: ORDER BY Ten (A-Z)
-- FIXME: Có 2 câu SELECT liên tiếp nhưng thiếu dấu ';' phân cách → câu 1 không chạy được (bị gộp)
--        Cần thêm ';' hoặc 'GO' giữa 2 câu
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenKhoa, MSSV, Ten as 'Tên Sinh Viên', DiaChi 
FROM KHOA  INNER JOIN SINHVIEN ON KHOA.MaKhoa=SINHVIEN.MaKhoa
SELECT K.MaKHoa,TenKhoa, MSSV, 'Tên Sinh Viên' = Ten, DiaChi 
FROM KHOA K  INNER JOIN SINHVIEN S ON K.MaKhoa=S.MaKhoa
ORDER BY Ten
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q11] Tên môn học, tên SV, điểm tổng kết theo từng khóa
-- NOTE: JOIN 4 bảng: KETQUA ↔ SINHVIEN ↔ GIANGDAY ↔ MONHOC
-- NOTE: Không có điều kiện lọc → tất cả kết quả
-- ═══════════════════════════════════════════════════════════════════════════
SELECT m.TenMH, s.Ten, kq.DiemKhoaHoc 
FROM KETQUA kq
JOIN SINHVIEN s ON kq.MSSV = s.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
JOIN MONHOC m ON g.MaMH = m.MaMH;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q12] SV học môn 'CSDL' có điểm 6-7
-- NOTE: Lọc MaMH='CSDL' AND DiemKhoaHoc BETWEEN 6 AND 7
-- ═══════════════════════════════════════════════════════════════════════════
SELECT s.Ten, kq.DiemKhoaHoc 
FROM KETQUA kq
JOIN SINHVIEN s ON kq.MSSV = s.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
WHERE g.MaMH = 'CSDL' AND kq.DiemKhoaHoc BETWEEN 6 AND 7;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q13] SV tên 'Tùng' - điểm các môn
-- NOTE: LIKE N'%Tùng' OR LIKE '%TUNG%' để bắt cả có dấu và không dấu
-- ═══════════════════════════════════════════════════════════════════════════
SELECT s.Ten, m.TenMH, g.MaKhoaHoc, kq.DiemKhoaHoc 
FROM KETQUA kq
JOIN SINHVIEN s ON kq.MSSV = s.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
JOIN MONHOC m ON g.MaMH = m.MaMH
WHERE s.Ten LIKE N'%Tùng' OR s.Ten LIKE '%TUNG%';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q14] Khoa + môn học mà SV khoa đó đã học (loại trùng)
-- NOTE: DISTINCT loại cặp (TenKhoa, TenMH) trùng
-- ═══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT k.TenKhoa, m.TenMH 
FROM SINHVIEN s
JOIN KHOA k ON s.MaKhoa = k.MaKhoa
JOIN KETQUA kq ON s.MSSV = kq.MSSV
JOIN GIANGDAY g ON kq.MaKhoaHoc = g.MaKhoaHoc
JOIN MONHOC m ON g.MaMH = m.MaMH;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q15] Khoa + mã khóa học mà GV của khoa tham gia dạy
-- NOTE: Chuỗi JOIN: KHOA → GIAOVIEN → GIANGDAY
-- ═══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT k.TenKhoa, g.MaKhoaHoc 
FROM GIAOVIEN gv
JOIN KHOA k ON gv.MaKhoa = k.MaKhoa
JOIN GIANGDAY g ON gv.MaGV = g.MaGV;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q16] GV tham gia dạy môn 'Kỹ thuật lập trình'
-- NOTE: Lọc TenMH = N'Kỹ thuật lập trình'
-- ═══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT gv.TenGV 
FROM GIAOVIEN gv
JOIN GIANGDAY g ON gv.MaGV = g.MaGV
JOIN MONHOC m ON g.MaMH = m.MaMH
WHERE m.TenMH = N'Kỹ thuật lập trình';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q17] SV có ít nhất 1 môn DiemKhoaHoc > 8
-- NOTE: Dùng DISTINCT để mỗi SV chỉ xuất hiện 1 lần dù nhiều môn >8
-- ═══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT s.MSSV, s.Ten 
FROM SINHVIEN s
JOIN KETQUA kq ON s.MSSV = kq.MSSV
WHERE kq.DiemKhoaHoc > 8;

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q18] SV học môn 'CSDL' HOẶC 'CTDL'
-- NOTE: Subquery dùng UNION để gộp MSSV đã học CSDL và CTDL
-- NOTE: Câu ngoài IN (subquery) để lọc
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q19] ❌ CHƯA CÓ CÂU TRẢ LỜI
-- NOTE: Đề bài: Tên môn học mà GV 'Tran Van Tien' dạy trong HK1 2012-2013
-- GỢI Ý: SELECT DISTINCT MH.TenMH FROM GIAOVIEN GV
--        JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
--        JOIN MONHOC MH ON GD.MaMH = MH.MaMH
--        WHERE GV.TenGV = N'Trần Văn Tiến' AND GD.HocKy=1 AND GD.NienKhoa='2012-2013'
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q20] Tên SV đã có điểm trong KETQUA (loại trùng tên)
-- NOTE: DISTINCT Ten để tránh trùng tên
-- ═══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT S.Ten AS N'Tên Sinh Viên'
FROM SINHVIEN S 
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q21] Hiển thị 35% dữ liệu KETQUA
-- NOTE: TOP 35 PERCENT
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TOP 35 PERCENT KQ.* FROM KETQUA KQ;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q22] 3 SV có điểm cao nhất (kèm đồng hạng)
-- NOTE: TOP (3) WITH TIES + ORDER BY DESC → lấy thêm các dòng đồng điểm thứ 3
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TOP (3) WITH TIES
       S.Ten           AS [Tên Sinh Viên],
       KQ.DiemKhoaHoc  AS [Điểm Khóa Học]
FROM SINHVIEN S
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
ORDER BY KQ.DiemKhoaHoc DESC;
GO

SELECT DISTINCT TOP (3) WITH TIES
       SV.Ten,
       KQ.DiemKhoaHoc
FROM KETQUA KQ
JOIN SINHVIEN SV ON KQ.MSSV = SV.MSSV
ORDER BY KQ.DiemKhoaHoc DESC;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q23] Môn học + điểm cao nhất của SV 'C0001F' (liệt kê đồng hạng)
-- NOTE: WHERE MSSV='C0001F' + TOP 1 WITH TIES + ORDER BY DESC
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TOP 1 WITH TIES M.TenMH AS N'Tên Môn Học', KQ.DiemKhoaHoc AS N'Điểm Lớn Nhất'
FROM KETQUA KQ JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
JOIN MONHOC M ON GD.MaMH = M.MaMH
WHERE KQ.MSSV = 'C0001F'
ORDER BY KQ.DiemKhoaHoc DESC
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q24] SV khoa TOAN có điểm > TẤT CẢ điểm của SV khoa khác
-- NOTE: Dùng > (subquery MAX của SV không thuộc TOAN)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT DISTINCT S.Ten AS N'Tên Sinh Viên'
FROM SINHVIEN S JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE S.MaKhoa = 'TOAN' AND KQ.DiemKhoaHoc > (
    SELECT MAX(DiemKhoaHoc) 
    FROM KETQUA K JOIN SINHVIEN V ON K.MSSV = V.MSSV 
    WHERE V.MaKhoa <> 'TOAN'
)
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q25] ❌ CHƯA CÓ CÂU TRẢ LỜI
-- NOTE: SV không thuộc CNTT có năm sinh < năm sinh của BẤT KỲ SV CNTT nào
-- GỢI Ý: ... WHERE YEAR(NgaySinh) < ALL(SELECT YEAR(NgaySinh) FROM SINHVIEN WHERE MaKhoa='CNTT')
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q26] ❌ CHƯA CÓ CÂU TRẢ LỜI - 3 cách (INNER JOIN / IN / EXISTS)
-- NOTE: Đề: Tên khoa CÓ sinh viên theo học
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q27] SV có tháng sinh trùng nhau - 2 cách
-- NOTE: Self-join SINHVIEN S1 ↔ S2, ON MONTH(S1.NgaySinh)=MONTH(S2.NgaySinh)
-- NOTE: WHERE S1.MSSV < S2.MSSV để tránh cặp trùng & không tự so chính mình
-- ═══════════════════════════════════════════════════════════════════════════
SELECT S1.Ten AS N'Tên SV (X)', S1.NgaySinh AS N'Ngày Sinh (X)', 
       S2.Ten AS N'Tên SV (Y)', S2.NgaySinh AS N'Ngày Sinh (Y)'
FROM SINHVIEN S1 JOIN SINHVIEN S2 ON MONTH(S1.NgaySinh) = MONTH(S2.NgaySinh)
WHERE S1.MSSV < S2.MSSV;
GO

SELECT S1.Ten AS N'Tên SV (X)', S1.NgaySinh AS N'Ngày Sinh (X)', 
       S2.Ten AS N'Tên SV (Y)', S2.NgaySinh AS N'Ngày Sinh (Y)'
FROM SINHVIEN S1, SINHVIEN S2
WHERE MONTH(S1.NgaySinh) = MONTH(S2.NgaySinh) AND S1.MSSV < S2.MSSV;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q28] 3 hàm xếp hạng: ROW_NUMBER / RANK / DENSE_RANK
-- NOTE: ROW_NUMBER: 1,2,3,4... không đồng hạng
-- NOTE: RANK: 1,2,2,4... nhảy bậc khi đồng hạng
-- NOTE: DENSE_RANK: 1,2,2,3... không nhảy bậc
-- ═══════════════════════════════════════════════════════════════════════════
SELECT S.Ten, KQ.DiemKhoaHoc,
    ROW_NUMBER() OVER(ORDER BY KQ.DiemKhoaHoc DESC) AS N'Row_Number',
    RANK() OVER(ORDER BY KQ.DiemKhoaHoc DESC) AS N'Rank',
    DENSE_RANK() OVER(ORDER BY KQ.DiemKhoaHoc DESC) AS N'Dense_Rank'
FROM SINHVIEN S JOIN KETQUA KQ ON S.MSSV = KQ.MSSV;
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q29-Q31] Hàm tổng hợp COUNT đơn giản
-- ═══════════════════════════════════════════════════════════════════════════
SELECT COUNT(MSSV) AS N'Số Lượng SV' FROM SINHVIEN;
GO
SELECT COUNT(MaGV) AS N'Số Lượng GV' FROM GIAOVIEN;
GO
SELECT COUNT(MaGV) AS N'Số GV CNTT' 
FROM GIAOVIEN 
WHERE MaKhoa = 'CNTT';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q32] SV nữ khoa CNTT
-- NOTE: PhaiNu = 1 (Nữ) AND MaKhoa = 'CNTT'
-- ═══════════════════════════════════════════════════════════════════════════
SELECT COUNT(MSSV) AS N'Số SV Nữ CNTT' 
FROM SINHVIEN 
WHERE MaKhoa = 'CNTT' AND PhaiNu = 1;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q33] Số môn học dạy trong HK1 2011-2012
-- NOTE: COUNT(DISTINCT MaMH) vì 1 môn có thể mở nhiều khóa
-- ═══════════════════════════════════════════════════════════════════════════
SELECT COUNT(DISTINCT MaMH) AS N'Số Môn Học' 
FROM GIANGDAY 
WHERE HocKy = 1 AND NienKhoa = '2011-2012';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q34] Số SV học môn CSDL
-- NOTE: JOIN KETQUA ↔ GIANGDAY, lọc MaMH='CSDL'
-- ═══════════════════════════════════════════════════════════════════════════
SELECT COUNT(DISTINCT KQ.MSSV) AS N'Số SV Học CSDL'
FROM KETQUA KQ JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
WHERE GD.MaMH = 'CSDL';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q35] SV 'T0003M' - số môn + điểm TB
-- NOTE: COUNT + AVG, ROUND(...,2) làm tròn 2 chữ số
-- ═══════════════════════════════════════════════════════════════════════════
SELECT COUNT(MaKhoaHoc) AS N'Số Môn Tham Gia', ROUND(AVG(DiemKhoaHoc), 2) AS N'Điểm TB'
FROM KETQUA
WHERE MSSV = 'T0003M';
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q36] Mã, tên, địa chỉ, điểm TB của TỪNG SV
-- NOTE: LEFT JOIN để SV chưa thi vẫn hiện (AVG=NULL)
-- NOTE: GROUP BY đủ các cột không tổng hợp
-- ═══════════════════════════════════════════════════════════════════════════
SELECT S.MSSV, S.Ten, S.DiaChi, ROUND(AVG(KQ.DiemKhoaHoc), 2) AS N'Điểm TB'
FROM SINHVIEN S LEFT JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten, S.DiaChi;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q37] Đếm số môn >=8 của từng SV (chỉ SV có môn >=8)
-- NOTE: INNER JOIN + WHERE lọc >=8 + GROUP BY
-- ═══════════════════════════════════════════════════════════════════════════
SELECT S.Ten AS N'Tên Sinh Viên', COUNT(KQ.MaKhoaHoc) AS N'Số Môn Điểm >= 8'
FROM SINHVIEN S JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE KQ.DiemKhoaHoc >= 8
GROUP BY S.MSSV, S.Ten;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q38] Tên khoa + số SV (chỉ khoa có SV)
-- NOTE: INNER JOIN → tự động loại khoa không có SV
-- ═══════════════════════════════════════════════════════════════════════════
SELECT K.TenKhoa, COUNT(SV.MSSV) AS N'SL Khoá Học'
FROM Khoa K
JOIN SinhVien SV ON SV.MaKhoa = K.MaKhoa
GROUP BY K.TenKhoa
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q39] Khoa + số khóa học GV khoa đó dạy
-- NOTE: COUNT(DISTINCT MaKhoaHoc) vì 1 GV có thể dạy nhiều khóa/môn
-- ═══════════════════════════════════════════════════════════════════════════
SELECT  K.TenKhoa, COUNT(DISTINCT GD.MaKhoaHoc) AS N'SL Khóa Học'
FROM Khoa K
JOIN GiaoVien GV ON K.MaKhoa = GV.MaKhoa
JOIN GiangDay GD ON GV.MaGV = GD.MaGV
GROUP BY K.MaKhoa, K.TenKhoa
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q40] SV + tổng TC lý thuyết + tổng TC thực hành
-- NOTE: Subquery gộp trước (GROUP BY KQ.MSSV) rồi JOIN với SINHVIEN
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q41] TẤT CẢ GV + số khóa + tổng TC (kể cả GV không dạy)
-- NOTE: LEFT JOIN + ISNULL(...,0) → GV không dạy vẫn hiện 0
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q42] Thống kê SV theo nhóm điểm (làm tròn 0 chữ số)
-- NOTE: ROUND(DiemKhoaHoc,0) làm nhóm, COUNT(DISTINCT MSSV) đếm SV
-- ═══════════════════════════════════════════════════════════════════════════
SELECT ROUND(DiemKhoaHoc, 0) AS DiemKhoaHoc_PhanNhom, 
       COUNT(DISTINCT MSSV) AS SoLuongSinhVien
FROM KETQUA
WHERE DiemKhoaHoc IS NOT NULL
GROUP BY ROUND(DiemKhoaHoc, 0);
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q43] SV chỉ thi đúng 1 môn
-- NOTE: GROUP BY + HAVING COUNT(...)=1
-- ═══════════════════════════════════════════════════════════════════════════
SELECT S.Ten AS N'Tên Sinh Viên'
FROM SINHVIEN S
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten
HAVING COUNT(KQ.MaKhoaHoc) = 1;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q44] SV có điểm TB > 8.5
-- BUG: Query này SAI - GROUP BY cả DiemKhoaHoc nên AVG = chính nó, không phải TB
--       Sửa: bỏ KQ.DiemKhoaHoc khỏi SELECT, hoặc dùng HAVING AVG() và subquery
-- ═══════════════════════════════════════════════════════════════════════════
SELECT SV.MSSV, SV.Ten, SV.DiaChi, KQ.DiemKhoaHoc
FROM SinhVien SV
JOIN KetQua KQ ON KQ.MSSV = SV.MSSV
GROUP BY SV.MSSV, SV.Ten, SV.DiaChi, KQ.DiemKhoaHoc
HAVING AVG(KQ.DiemKhoaHoc) > 8.5
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q45] Khóa học có 2-4 SV tham gia
-- FIXME: Lỗi chính tả cột 'NieuKhoa' - phải là 'NienKhoa'
-- ═══════════════════════════════════════════════════════════════════════════
SELECT GD.MaKhoaHoc, GD.HocKy, GD.NieuKhoa, COUNT(KQ.MSSV) AS SLSV
FROM GiangDay GD
JOIN KetQua KQ ON KQ.MaKhoaHoc = GD.MaKhoaHoc
GROUP BY GD.MaKhoaHoc, GD.HocKy, GD.NieuKhoa
HAVING COUNT(KQ.MSSV) BETWEEN 2 AND 4

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q46] ❌ BỊ THIẾU
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q47] Trả lời Có/Không bằng EXISTS + CASE
-- NOTE: CASE WHEN EXISTS(...) THEN N'Có' ELSE N'Không' END
-- ═══════════════════════════════════════════════════════════════════════════

-- NOTE: [47a] SV C0001F có tham gia K001 không?
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 
        FROM KETQUA 
        WHERE MSSV = 'C0001F' AND MaKhoaHoc = 'K001'
    ) 
    THEN N'Có' ELSE N'Không' END AS [47a];

-- NOTE: [47b] Khóa K001 có SV thi lại (điểm <5) không?
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 
        FROM KETQUA 
        WHERE MaKhoaHoc = 'K001' AND DiemKhoaHoc < 5
    ) 
    THEN N'Có' ELSE N'Không' END AS [47b]

-- NOTE: [47c] Khoa CNTT có SV Nữ đạt >=5 CẢ 2 môn CSDL & CTDL?
-- NOTE: GROUP BY S.MSSV + HAVING COUNT(DISTINCT MaMH)=2 → SV phải học đủ 2 môn
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

-- NOTE: [47d] GV 'Thảo' có dạy năm 2011-2012 không?
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 
        FROM GIAOVIEN GV
        JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
        WHERE (GV.TenGV LIKE N'%Thảo' OR GV.TenGV LIKE '%THAO%')
          AND GD.NienKhoa = '2011-2012'
    ) 
    THEN N'Có' ELSE N'Không' END AS [47d]

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q48] Tính học bổng: >=7 → 1tr, còn lại 0
-- NOTE: CASE WHEN AVG(...) >= 7 + GROUP BY
-- ═══════════════════════════════════════════════════════════════════════════
SELECT S.MSSV, S.Ten AS N'Họ tên',
    CASE 
        WHEN AVG(KQ.DiemKhoaHoc) >= 7 THEN 1000000 
        ELSE 0 
    END AS [Học bổng]
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten;

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q49] Xếp loại theo điểm TB
-- NOTE: CASE nhiều nhánh: >=8 Giỏi, >=6.5 Khá, >=5 TB, còn lại Yếu
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q50] ❌ BỊ THIẾU
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q51] Khoa có SL_CBGD ít nhất - 3 cách
-- NOTE: C1 dùng MIN, C2 dùng <= ALL, C3 dùng TOP 1 WITH TIES
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenKhoa
FROM Khoa
WHERE SL_CBGD = (SELECT MIN(SL_CBGD) FROM Khoa)

SELECT TenKhoa
FROM Khoa
WHERE SL_CBGD <= ALL (SELECT SL_CBGD FROM Khoa)

SELECT TOP 1 WITH TIES TenKhoa, SL_CBGD
FROM KHOA
ORDER BY SL_CBGD
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q52] SV có điểm cao nhất khóa 'K001' - 2 cách
-- NOTE: C1 TOP 1 WITH TIES, C2 subquery MAX
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TOP 1 WITH TIES S.MSSV, S.Ten AS N'Tên Sinh Viên', S.DiaChi
FROM SINHVIEN S
INNER JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE KQ.MaKhoaHoc = 'K001'
ORDER BY KQ.DiemKhoaHoc DESC;

SELECT S.MSSV, S.Ten AS N'Tên Sinh Viên', S.DiaChi
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
WHERE KQ.MaKhoaHoc = 'K001' 
  AND KQ.DiemKhoaHoc = (
      SELECT MAX(DiemKhoaHoc) FROM KETQUA WHERE MaKhoaHoc = 'K001'
  );
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q53] SV điểm cao nhất môn 'Kỹ thuật lập trình' - 3 cách
-- NOTE: C1 MAX, C2 >= ALL, C3 TOP 1 WITH TIES
-- BUG: C1 và C2 dùng alias 'M' nhưng subquery không reference đúng - vẫn chạy được nhưng logic hơi khó hiểu
-- ═══════════════════════════════════════════════════════════════════════════
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

SELECT TOP 1 WITH TIES SV.Ten, KQ.DiemKhoaHoc
FROM KetQua KQ
JOIN SinhVien SV ON SV.MSSV = KQ.MSSV
JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
JOIN MonHoc MH ON GD.MaMH = MH.MaMH
WHERE MH.TenMH LIKE N'%Kỹ thuật lập trình'
ORDER BY KQ.DiemKhoaHoc DESC
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q54] GV dạy nhiều khóa nhất - 4 cách
-- NOTE: C1 TOP WITH TIES, C2 >= ALL, C3 MAX subquery, C4 RANK window function
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TOP 1 WITH TIES GV.TenGV
FROM GIAOVIEN GV
JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
GROUP BY GV.MaGV, GV.TenGV
ORDER BY COUNT(GD.MaKhoaHoc) DESC

SELECT GV.TenGV
FROM GIAOVIEN GV
JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
GROUP BY GV.MaGV, GV.TenGV
HAVING COUNT(GD.MaKhoaHoc) >= ALL (
    SELECT COUNT(MaKhoaHoc) FROM GIANGDAY GROUP BY MaGV
)

SELECT GV.TenGV
FROM GIAOVIEN GV
JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
GROUP BY GV.MaGV, GV.TenGV
HAVING COUNT(GD.MaKhoaHoc) = (
    SELECT MAX(SoKhoaHoc) FROM (
        SELECT COUNT(MaKhoaHoc) AS SoKhoaHoc FROM GIANGDAY GROUP BY MaGV
    ) T
)

SELECT TenGV 
FROM (
    SELECT GV.TenGV, RANK() OVER(ORDER BY COUNT(GD.MaKhoaHoc) DESC) AS XepHang
    FROM GIAOVIEN GV
    JOIN GIANGDAY GD ON GV.MaGV = GD.MaGV
    GROUP BY GV.MaGV, GV.TenGV
) BangXepHang
WHERE XepHang = 1
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q55] Điểm cao nhất của TỪNG SV - 3 cách
-- NOTE: C1 GROUP BY + MAX, C2 subquery tương quan, C3 window function MAX() OVER(PARTITION BY)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT S.MSSV, S.Ten AS N'Tên Sinh Viên', MAX(KQ.DiemKhoaHoc) AS N'Điểm Cao Nhất'
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV
GROUP BY S.MSSV, S.Ten

SELECT S.MSSV, S.Ten AS N'Tên Sinh Viên', 
       (SELECT MAX(DiemKhoaHoc) FROM KETQUA WHERE MSSV = S.MSSV) AS N'Điểm Cao Nhất'
FROM SINHVIEN S
WHERE EXISTS (SELECT 1 FROM KETQUA WHERE MSSV = S.MSSV) 

SELECT DISTINCT S.MSSV, S.Ten AS N'Tên Sinh Viên', 
       MAX(KQ.DiemKhoaHoc) OVER(PARTITION BY S.MSSV) AS N'Điểm Cao Nhất'
FROM SINHVIEN S
JOIN KETQUA KQ ON S.MSSV = KQ.MSSV

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q56] Điểm cao nhất của TỪNG môn - 2 cách
-- NOTE: C1 GROUP BY môn + MAX, C2 subquery tương quan + EXISTS
-- ═══════════════════════════════════════════════════════════════════════════
SELECT MH.TenMH, MAX(KQ.DiemKhoaHoc) AS N'Điểm Cao Nhất'
FROM MONHOC MH
JOIN GIANGDAY GD ON MH.MaMH = GD.MaMH
JOIN KETQUA KQ ON GD.MaKhoaHoc = KQ.MaKhoaHoc
GROUP BY MH.MaMH, MH.TenMH

SELECT MH.TenMH, 
       (SELECT MAX(KQ.DiemKhoaHoc) 
        FROM KETQUA KQ 
        JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc 
        WHERE GD.MaMH = MH.MaMH) AS N'Điểm Cao Nhất'
FROM MONHOC MH
WHERE EXISTS (
    SELECT 1 FROM KETQUA KQ 
    JOIN GIANGDAY GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc 
    WHERE GD.MaMH = MH.MaMH
)

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q57] Học kỳ có nhiều môn nhất - 3 cách
-- NOTE: COUNT(DISTINCT MaMH) + GROUP BY HocKy
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TOP 1 WITH TIES HocKy
FROM GIANGDAY
GROUP BY HocKy
ORDER BY COUNT(DISTINCT MaMH) DESC;

SELECT HocKy
FROM GIANGDAY
GROUP BY HocKy
HAVING COUNT(DISTINCT MaMH) >= ALL (
    SELECT COUNT(DISTINCT MaMH) FROM GIANGDAY GROUP BY HocKy
)

SELECT HocKy
FROM (
    SELECT HocKy, RANK() OVER(ORDER BY COUNT(DISTINCT MaMH) DESC) AS XepHang
    FROM GIANGDAY
    GROUP BY HocKy
) T
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q58-Q65] ❌ BỊ THIẾU
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q66] Tên SV + điểm TB + số khóa học
-- NOTE: LEFT JOIN để SV chưa thi vẫn hiện
-- NOTE: IIF/ISNULL để thay NULL bằng thông báo
-- NOTE: ROUND + CAST DECIMAL(4,2) định dạng 2 chữ số lẻ
-- ═══════════════════════════════════════════════════════════════════════════
SELECT SV.Ten, IIF(
                    AVG(KQ.DiemKhoaHoc) IS NULL, 
                    N'SV chưa thi bất kỳ môn học nào', 
                    CAST(CAST(ROUND(AVG(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50))
                  ) AS DiemTrungBinh, COUNT(KQ.MaKhoaHoc) AS SLKhoaHoc
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
GROUP BY SV.MSSV, SV.Ten;

SELECT SV.Ten, ISNULL(
                       CAST(CAST(ROUND(AVG(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50)),
                       N'SV chưa thi bất kỳ môn học nào'
                     ) AS DiemTrungBinh, COUNT(KQ.DiemKhoaHoc) AS SLKhoaHoc
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
GROUP BY SV.MSSV, SV.Ten
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q67] Tổng TC của từng SV
-- NOTE: LEFT JOIN + ISNULL/IIF để SV chưa học = 0
-- ═══════════════════════════════════════════════════════════════════════════
SELECT SV.MSSV, SV.Ten, IIF (
                              SUM(GD.TongSoTC) IS NULL,0,
                              SUM(GD.TongSoTC)
                            ) AS TongSoTinChi
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
LEFT JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
GROUP BY SV.MSSV, SV.Ten

SELECT SV.MSSV, SV.Ten, ISNULL(SUM(GD.TongSoTC), 0) AS TongSoTinChi
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
LEFT JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
GROUP BY SV.MSSV, SV.Ten;
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q68] Tên môn + SL SV có điểm + điểm nhỏ nhất
-- NOTE: LEFT JOIN để môn chưa có SV vẫn hiện
-- NOTE: IIF/ISNULL thay NULL bằng 'Chưa có SV có điểm môn học này'
-- BUG: Đặt tên cột là DiemTrungBinh nhưng thực chất là MIN → nên đổi thành DiemNhoNhat
-- ═══════════════════════════════════════════════════════════════════════════
SELECT MH.TenMH, COUNT(KQ.DiemKhoaHoc) AS SLSV, IIF(
                                                      MIN(KQ.DiemKhoaHoc) IS NULL,
                                                      N'Chưa có SV có điểm môn học này',
                                                      CAST(CAST(ROUND(MIN(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50))
                                                   ) AS DiemTrungBinh
FROM MonHoc MH
LEFT JOIN GiangDay GD ON MH.MaMH = GD.MaMH
LEFT JOIN KetQua KQ ON GD.MaKhoaHoc = KQ.MaKhoaHoc
GROUP BY MH.MaMH, MH.TenMH

SELECT MH.TenMH, COUNT(KQ.DiemKhoaHoc) AS SLSV, ISNULL(
                                                              CAST(CAST(ROUND(MIN(KQ.DiemKhoaHoc), 2) AS DECIMAL(4, 2)) AS NVARCHAR(50)),
                                                              N'Chưa có SV có điểm môn học này'
                                                            ) AS DiemTrungBinh
FROM MonHoc MH
LEFT JOIN GiangDay GD ON MH.MaMH = GD.MaMH
LEFT JOIN KetQua KQ ON GD.MaKhoaHoc = KQ.MaKhoaHoc
GROUP BY MH.MaMH, MH.TenMH
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q69] Tên khoa + số SV - TẤT CẢ khoa (kể cả 0 SV)
-- NOTE: LEFT JOIN KHOA → SINHVIEN (ngược Q38)
-- ═══════════════════════════════════════════════════════════════════════════
SELECT k.TenKhoa,COUNT(sv.MSSV) AS [SL SV]
FROM Khoa k
LEFT JOIN SinhVien sv ON k.MaKhoa = sv.MaKhoa
GROUP BY k.MaKhoa, k.TenKhoa
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q70] Tên khoa + số khóa học - TẤT CẢ khoa
-- NOTE: LEFT JOIN 2 lần KHOA → GV → GIANGDAY
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenKhoa, COUNT(DISTINCT MaKhoaHoc) AS SLKhoaHoc
FROM Khoa K
LEFT JOIN GiaoVien GV ON K.MaKhoa = GV.MaKhoa
LEFT JOIN GiangDay GD ON GV.MaGV = GD.MaGV
GROUP BY TenKhoa

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q71] Đếm số môn >=8 của từng SV - TẤT CẢ SV
-- NOTE: LEFT JOIN + SUM(IIF(điều_kiện, 1, 0)) + ISNULL
-- ═══════════════════════════════════════════════════════════════════════════
SELECT SV.MSSV, SV.Ten, ISNULL(SUM(IIF(KQ.DiemKhoaHoc >= 8, 1, 0)), 0) AS SLDiemKhoaHoc
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
GROUP BY SV.MSSV, SV.Ten
GO

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q72] Môn học CHƯA được tổ chức - 3 cách
-- NOTE: C1 EXCEPT, C2 NOT IN, C3 LEFT JOIN ... IS NULL
-- ═══════════════════════════════════════════════════════════════════════════
SELECT TenMH 
FROM MonHoc 
WHERE MaMH IN (
                SELECT MaMH FROM MonHoc
                EXCEPT
                SELECT MaMH FROM GiangDay
              )

SELECT TenMH
FROM MonHoc
WHERE MaMH NOT IN (
                    SELECT MaMH FROM GiangDay WHERE MaMH IS NOT NULL
                  )

SELECT MH.TenMH
FROM MonHoc MH
LEFT JOIN GiangDay GD ON MH.MaMH = GD.MaMH
WHERE GD.MaMH IS NULL

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q73] SV chưa có bất kỳ điểm nào - 3 cách
-- NOTE: C1 NOT IN, C2 LEFT JOIN IS NULL, C3 EXCEPT
-- ═══════════════════════════════════════════════════════════════════════════
SELECT Ten
FROM SinhVien SV
WHERE MSSV NOT IN (
                    SELECT MSSV FROM KetQua WHERE MSSV IS NOT NULL
                  )

SELECT SV.Ten 
FROM SinhVien SV
LEFT JOIN KetQua KQ ON SV.MSSV = KQ.MSSV
WHERE KQ.MSSV IS NULL

SELECT Ten
FROM SinhVien 
WHERE MSSV IN (
                SELECT MSSV FROM SinhVien
                EXCEPT
                SELECT MSSV FROM KetQua
              )

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q74-Q81] ❌ BỊ THIẾU
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q82] GV dạy ĐỦ TẤT CẢ các môn (phép chia quan hệ)
-- NOTE: Double NOT EXISTS: "không tồn tại môn nào mà GV không dạy"
-- ═══════════════════════════════════════════════════════════════════════════
SELECT GV.TenGV
FROM GiaoVien GV
WHERE NOT EXISTS (
                  SELECT 1 FROM MonHoc MH
                  WHERE NOT EXISTS (
                                     SELECT 1 FROM GiangDay GD 
                                     WHERE GD.MaGV = GV.MaGV AND GD.MaMH = MH.MaMH
                                    )
                )

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q83] Môn học mà TẤT CẢ GV đều dạy (phép chia quan hệ)
-- NOTE: Double NOT EXISTS tương tự Q82
-- ═══════════════════════════════════════════════════════════════════════════
SELECT MH.TenMH
FROM MonHoc MH
WHERE NOT EXISTS (
                  SELECT 1 FROM GiaoVien GV
                  WHERE NOT EXISTS (
                                     SELECT 1 FROM GiangDay GD 
                                     WHERE GD.MaMH = MH.MaMH AND GD.MaGV = GV.MaGV
                                   )
                 )

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q84] Khóa học mà TẤT CẢ SV đều tham gia
-- NOTE: Double NOT EXISTS
-- ═══════════════════════════════════════════════════════════════════════════
SELECT GD.MaKhoaHoc
FROM GiangDay GD
WHERE NOT EXISTS (
    SELECT 1 FROM SinhVien SV
    WHERE NOT EXISTS (
        SELECT 1 FROM KetQua KQ
        WHERE KQ.MaKhoaHoc = GD.MaKhoaHoc AND KQ.MSSV = SV.MSSV
    )
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q85] SV tham gia ĐỦ TẤT CẢ khóa học
-- NOTE: Double NOT EXISTS
-- ═══════════════════════════════════════════════════════════════════════════
SELECT SV.Ten
FROM SinhVien SV
WHERE NOT EXISTS (
    SELECT 1 FROM GiangDay GD
    WHERE NOT EXISTS (
        SELECT 1 FROM KetQua KQ
        WHERE KQ.MSSV = SV.MSSV AND KQ.MaKhoaHoc = GD.MaKhoaHoc
    )
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q86] Môn học mà TẤT CẢ SV đều học
-- NOTE: Double NOT EXISTS + JOIN KETQUA ↔ GIANGDAY
-- ═══════════════════════════════════════════════════════════════════════════
SELECT MH.TenMH
FROM MonHoc MH
WHERE NOT EXISTS (
    SELECT 1 FROM SinhVien SV
    WHERE NOT EXISTS (
        SELECT 1 FROM KetQua KQ 
        JOIN GiangDay GD ON KQ.MaKhoaHoc = GD.MaKhoaHoc
        WHERE GD.MaMH = MH.MaMH AND KQ.MSSV = SV.MSSV
    )
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q87-Q89] ❌ BỊ THIẾU
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q90] Thêm cột tính toán vào bảng SINHVIEN
-- NOTE: ALTER TABLE DROP nếu đã tồn tại → tránh lỗi "column already exists"
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE SINHVIEN 
DROP COLUMN SLMon, DTB, DTBTichLuy, SoTCTichLuy, XL;
ALTER TABLE SINHVIEN
ADD 
    SLMon INT, DTB FLOAT, DTBTichLuy FLOAT, SoTCTichLuy INT, XL NVARCHAR(20);

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q91] Cập nhật dữ liệu các cột mới
-- ═══════════════════════════════════════════════════════════════════════════

-- NOTE: [91a] Cập nhật NgayNhapHoc theo khoa
UPDATE SINHVIEN
SET NgayNhapHoc = CASE 
    WHEN MaKhoa = 'CNTT' THEN '2011-11-15'
    WHEN MaKhoa = 'TOAN' THEN '2011-10-22'
    ELSE NgayNhapHoc
END

-- NOTE: [91b] SLMon = số môn đã có điểm
UPDATE SINHVIEN
SET SLMon = (
    SELECT COUNT(*) FROM KETQUA WHERE KETQUA.MSSV = SINHVIEN.MSSV
)

-- NOTE: [91c] DTB = tổng điểm / SLMon
-- FIXME: Nếu SLMon = 0 → chia cho 0 gây lỗi
UPDATE SINHVIEN
SET DTB = (
    SELECT SUM(DiemKhoaHoc) / SLMon
    FROM KETQUA
    WHERE KETQUA.MSSV = SINHVIEN.MSSV
)

-- NOTE: [91d] DTBTichLuy - đổi kiểu sang nvarchar(30), tính AVG điểm >=5
ALTER TABLE SinhVien
ALTER COLUMN DTBTichLuy nvarchar(30);

UPDATE SinhVien
SET DTBTichLuy = (
    SELECT ISNULL(AVG(DiemKhoaHoc), 0)
    FROM KetQua
    WHERE KetQua.MSSV = SinhVien.MSSV
    AND DiemKhoaHoc >= 5
)

-- NOTE: [91e] SoTCTichLuy - tổng TC môn >=5
UPDATE SinhVien
SET SoTCTichLuy = (
    SELECT ISNULL(SUM(GiangDay.TongSoTC), 0)
    FROM KetQua
    JOIN GiangDay ON KetQua.MaKhoaHoc = GiangDay.MaKhoaHoc
    WHERE KetQua.MSSV = SinhVien.MSSV
    AND DiemKhoaHoc >= 5
)

-- NOTE: [91f] XepLoai - thêm cột mới (khác với XL ở Q90)
-- BUG: DTBTichLuy là nvarchar(30) nhưng so sánh với số (< 5.0) → SQL Server tự convert
--      Nếu DTBTichLuy = '0' thì vẫn so sánh được, nhưng nếu NULL thì vào nhánh 'Chưa xếp loại'
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

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q92] Thêm cột Học bổng - 2 lần làm
-- NOTE: Lần 1 dùng NVARCHAR, lần 2 dùng INT (bị trùng cột → cần DROP trước)
-- BUG: Lần 1 ADD HocBong NVARCHAR(30), lần 2 lại ADD HocBong INT → lỗi "column already exists"
-- ═══════════════════════════════════════════════════════════════════════════
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

-- Lần 2 dùng INT
ALTER TABLE SinhVien
ADD HocBong INT   -- FIXME: Sẽ lỗi vì HocBong đã tồn tại

UPDATE SinhVien
SET HocBong = CASE
    WHEN DTBTichLuy IS NOT NULL AND DTBTichLuy <> '0' AND CAST(DTBTichLuy AS FLOAT) >= 9.0
        THEN 2000000
    WHEN DTBTichLuy IS NOT NULL AND DTBTichLuy <> '0' AND CAST(DTBTichLuy AS FLOAT) >= 8.0
        THEN 1000000
    ELSE 0
END

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q93] Xóa kết quả học tập của SV 'C0002M'
-- ═══════════════════════════════════════════════════════════════════════════
DELETE FROM KETQUA
WHERE MSSV = 'C0002M'

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q94] Xóa SV có DTBTichLuy < 5 hoặc NULL
-- NOTE: Cần xóa KETQUA trước nếu có FK constraint (hoặc dùng CASCADE)
-- BUG: Nếu KETQUA còn tham chiếu MSSV thì DELETE sẽ lỗi FK
-- ═══════════════════════════════════════════════════════════════════════════
DELETE FROM SINHVIEN
WHERE DTBTichLuy < 5 OR DTBTichLuy IS NULL

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q95] Xóa khoa không có SV
-- NOTE: NOT IN (subquery) - các khoa không xuất hiện trong SINHVIEN
-- ═══════════════════════════════════════════════════════════════════════════
DELETE KHOA
WHERE MaKhoa NOT IN (SELECT MaKhoa FROM SINHVIEN)

SELECT * FROM khoa

-- ═══════════════════════════════════════════════════════════════════════════
-- TODO: [Q96] Import dữ liệu từ bảng tạm (Khoa_tmp) - tránh trùng bằng NOT EXISTS
-- NOTE: INSERT ... SELECT ... WHERE NOT EXISTS
-- NOTE: Sau khi xong thì DROP TABLE tạm
-- ═══════════════════════════════════════════════════════════════════════════
SELECT * FROM Khoa_tmp;
SELECT * FROM Khoa;

INSERT INTO Khoa (MaKhoa, TenKhoa, SL_CBGD)
SELECT t.MaKhoa, t.TenKhoa, t.SL_CBGD
FROM Khoa_tmp t
WHERE NOT EXISTS (SELECT 1 FROM Khoa k WHERE k.MaKhoa = t.MaKhoa);

DROP TABLE Khoa_tmp;