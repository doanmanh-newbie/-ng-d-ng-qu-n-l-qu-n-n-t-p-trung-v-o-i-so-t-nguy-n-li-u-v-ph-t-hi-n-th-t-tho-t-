-- =====================================================================
-- Fore · 006_evaluate_simulation.sql · Đo khả năng phát hiện trên dữ liệu MÔ PHỎNG
-- Chạy SAU 005_sim_data.sql. Kết quả (3 bảng) dùng trực tiếp cho báo cáo.
-- Định nghĩa: một ca "bị báo" nếu có ít nhất 1 nguyên liệu ở mức warn (vàng) hoặc alert (đỏ).
-- =====================================================================

create temp table sim_eval as
select g.day_no, g.scenario, g.hidden_cups,
       bool_or(r.status in ('warn', 'alert')) as flagged,
       bool_or(r.status = 'alert')            as flagged_red,
       max(abs(r.adjusted_pct))               as worst_pct,
       string_agg(r.ingredient_name || ' ' || r.adjusted_pct || '%', ', ' order by abs(r.adjusted_pct) desc)
         filter (where r.status in ('warn', 'alert')) as flagged_items
  from sim_ground_truth g
  cross join lateral reconcile_shift(g.shift_id) r
 group by g.day_no, g.scenario, g.hidden_cups;

-- 1) Tỉ lệ phát hiện theo kịch bản
select scenario as "Kịch bản", count(*) as "Số ca",
       count(*) filter (where flagged) as "Bị báo (vàng/đỏ)",
       count(*) filter (where flagged_red) as "Bị báo đỏ",
       round(100.0 * count(*) filter (where flagged) / count(*), 0) as "% phát hiện"
  from sim_eval where scenario <> 'none' group by scenario order by scenario;

-- 2) Báo nhầm (ca sạch bị báo)
select count(*) as "Ca sạch", count(*) filter (where flagged) as "Báo nhầm (vàng/đỏ)",
       count(*) filter (where flagged_red) as "Báo nhầm đỏ",
       round(100.0 * count(*) filter (where flagged) / count(*), 1) as "% báo nhầm"
  from sim_eval where scenario = 'none';

-- 3) Chi tiết từng ngày (để đối chiếu)
select day_no as "Ngày", scenario as "Kịch bản", hidden_cups as "Ly lậu",
       case when flagged_red then 'ĐỎ' when flagged then 'VÀNG' else 'xanh' end as "Kết quả",
       worst_pct as "Lệch lớn nhất %", flagged_items as "Nguyên liệu bị báo"
  from sim_eval order by day_no;
