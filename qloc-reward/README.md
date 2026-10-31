# QLOC Reward — Demo v1.0

Nền tảng nhiệm vụ và điểm thưởng nội bộ, giao diện glassmorphism. Bản này **chỉ là demo**, không phát hành tiền, không quy đổi ra VND và không thực hiện thanh toán/rút tiền thật.

## Công nghệ
- React + Vite
- Supabase Auth + PostgreSQL + Row Level Security
- Supabase RPC để ghi nhận hoàn thành nhiệm vụ và cộng điểm phía server
- CSS responsive, Lucide icons

## Chạy trên Ubuntu
Cần Node.js 20 trở lên.

```bash
unzip qloc-reward.zip
cd qloc-reward
npm install
cp .env.example .env
npm run dev
```
Mở địa chỉ được Vite hiển thị, thường là `http://localhost:5173`.

## Chạy demo không cần Supabase
Để nguyên `.env.example` (hoặc chưa tạo `.env`). Ứng dụng tự chạy local demo, số dư và lịch sử được lưu trong localStorage của trình duyệt. Dữ liệu demo không đồng bộ giữa thiết bị và có thể xóa khi xóa dữ liệu trình duyệt.

## Kết nối Supabase
1. Tạo project Supabase.
2. Mở **SQL Editor**, chạy toàn bộ nội dung `supabase/schema.sql`.
3. Vào **Project Settings → API** và sao chép Project URL cùng anon/public key.
4. Điền vào `.env`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_ANON_PUBLIC_KEY
```

5. Khởi động lại `npm run dev`.
6. Đăng ký tài khoản mới. Supabase có thể yêu cầu xác nhận email tùy cấu hình Auth.

### Cấp quyền admin
Mặc định tất cả tài khoản là `user`. Chỉ chủ project mới nên tự cấp quyền cho tài khoản của mình sau khi đăng nhập:

```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'EMAIL_CUA_BAN');
```

Không cung cấp quyền admin cho người lạ. Admin hiện có thể quản lý nhiệm vụ qua SQL/Supabase dashboard; phần form quản trị trên frontend ở chế độ demo chỉ thêm dữ liệu cục bộ.

## Cấu trúc

```text
qloc-reward/
├── index.html
├── package.json
├── .env.example
├── README.md
├── src/
│   ├── main.jsx
│   ├── App.jsx
│   ├── style.css
│   └── supabase.js
└── supabase/
    └── schema.sql
```

## Lưu ý bảo mật và vận hành
- Chỉ dùng Supabase anon/public key ở frontend. Tuyệt đối không đưa `service_role` key vào `.env` frontend, GitHub hoặc trình duyệt.
- RLS giới hạn hồ sơ, ví, lịch sử và nhiệm vụ đã hoàn thành theo từng người dùng.
- Cộng điểm trong chế độ Supabase thực hiện bằng RPC phía database, tránh cho client tự gửi số điểm tùy ý.
- Nhiệm vụ link trong bản demo **không xác minh** lượt xem, lượt click hay hoàn thành offer từ nhà quảng cáo. Không dùng dữ liệu này để tính hoa hồng hoặc trả thưởng thật.
- Không có tỷ giá VND, cổng rút tiền, thông tin ngân hàng hoặc xử lý thanh toán. Muốn triển khai reward có giá trị thật cần rà soát pháp lý, hợp đồng nguồn quảng cáo, điều khoản mạng quảng cáo, thuế, bảo vệ dữ liệu và quy trình thanh toán trước.
