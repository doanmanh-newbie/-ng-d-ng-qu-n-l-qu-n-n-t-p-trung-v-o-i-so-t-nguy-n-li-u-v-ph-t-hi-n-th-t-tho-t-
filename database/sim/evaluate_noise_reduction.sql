-- =====================================================================
-- Fore · sim/evaluate_noise_reduction.sql · Đo hiệu quả GIẢM BÁO NHẦM trên dữ liệu MÔ PHỎNG
-- Chạy SAU sim/sim_data.sql và 009_shift_report.sql. Dùng shift_report cho từng ca mô phỏng.
-- So sánh 2 cách chủ "để ý" một ca (chỉ xét nguyên liệu):
--   Cách cũ : ca có ít nhất 1 nguyên liệu vàng hoặc đỏ
--   Cách mới: ca có nguyên liệu ĐỎ, hoặc có cờ XU HƯỚNG (nhiều ca liên tiếp lệch cùng chiều); vàng lẻ bỏ qua
-- Kết quả phụ thuộc cấu hình hiện tại (ngưỡng %, streak_shifts, ingredients.min_abs_qty).
-- Dữ liệu là giả lập: chỉ minh họa logic, không chứng minh độ chính xác ngoài thực tế.
-- =====================================================================
create temp table sim_noise as
select g.day_no, g.scenario, g.hidden_cups,
       ((s.j -> 'summary' ->> 'ingredient_alerts')::int + (s.j -> 'summary' ->> 'ingredient_warns')::int) > 0 as old_way,
       ((s.j -> 'summary' ->> 'ingredient_alerts')::int > 0 or (s.j -> 'summary' ->> 'streak_flags')::int > 0) as new_way
  from sim_ground_truth g
  cross join lateral (select shift_report(g.shift_id) as j) s;

select scenario as "Kịch bản", count(*) as "Số ca",
       count(*) filter (where old_way) as "Cách cũ bắt được",
       count(*) filter (where new_way) as "Cách mới bắt được"
  from sim_noise where scenario <> 'none' group by scenario order by scenario;

select count(*) as "Ca sạch",
       count(*) filter (where old_way) as "Cách cũ báo nhầm",
       count(*) filter (where new_way) as "Cách mới báo nhầm"
  from sim_noise where scenario = 'none';
