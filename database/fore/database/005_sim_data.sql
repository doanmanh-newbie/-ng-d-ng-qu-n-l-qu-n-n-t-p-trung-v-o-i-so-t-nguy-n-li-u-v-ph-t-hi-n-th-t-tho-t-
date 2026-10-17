-- =====================================================================
-- Fore · 005_sim_data.sql · DỮ LIỆU MÔ PHỎNG 30 NGÀY (KHÔNG PHẢI DỮ LIỆU THẬT)
-- Mục đích: kiểm tra Fore có phát hiện được gian lận đã cài sẵn hay không.
--   - Tạo nhân sự/nguyên liệu/menu mẫu (tên có tiền tố [MÔ PHỎNG]), 30 ca bán hàng, nhập kho, đếm kho cuối ca.
--   - Cài sẵn 4 kịch bản gian lận vào số tồn kho thật (xem bảng sim_ground_truth):
--       A  bán không lên bill (đá bill)  ngày 8-12, 12 ly/ngày
--       D  đá bill nhẹ                   ngày 15-16, 3 ly/ngày  (cố ý dưới ngưỡng: kiểm tra giới hạn phát hiện)
--       B  pha dư sữa +20%               ngày 19-21
--       C  mất 3.000 g trân châu         ngày 26
--   - Có nhiễu bình thường (±1-2%, đo lường sai số, hao hụt có lý do) để có thể báo nhầm.
-- Kết quả dùng được: chạy 006_evaluate_simulation.sql để lấy tỉ lệ phát hiện / báo nhầm cho báo cáo.
-- ĐỪNG CHẠY trên database có dữ liệu thật của quán. Dọn: dev/reset_all.sql (xóa toàn bộ).
-- Chạy SAU 004_reconcile.sql. Chạy bằng quyền quản trị (SQL Editor).
-- =====================================================================

create table if not exists sim_ground_truth (
  shift_id    uuid primary key references shifts(id),
  day_no      integer not null,
  scenario    text not null,          -- none | A_unbilled | D_small_unbilled | B_overpour | C_theft
  hidden_cups integer not null default 0,
  note        text
);
alter table sim_ground_truth enable row level security;
revoke all on sim_ground_truth from anon, authenticated;

do $sim$
declare
  day0 constant date := current_date - 30;
  v_owner uuid; v_a uuid; v_b uuid;
  v_milk uuid; v_tea uuid; v_coffee uuid; v_pearl uuid; v_sugar uuid;
  v_ts_m uuid; v_ts_l uuid; v_cf_s uuid; v_cf_b uuid;
  v_tables uuid[]; v_sizes uuid[];
  d int; v_shift uuid; v_staff uuid; v_open_ts timestamptz; v_close_ts timestamptz;
  v_scn text; v_hidden int; v_n_bills int; v_th int; v_use int; v_open int; v_purch int; v_close_true int;
  v_noise numeric; v_extra int; v_waste int; v_pack int; v_need int; v_cnt int; v_cash int;
  rec record;
  stock jsonb := '{}'::jsonb;          -- tồn thật theo ingredient_id
begin
  perform setseed(0.42);

  insert into staff (full_name, role) values ('[MÔ PHỎNG] Chủ quán', 'owner') returning id into v_owner;
  insert into staff (full_name, role) values ('[MÔ PHỎNG] Nhân viên A', 'staff') returning id into v_a;
  insert into staff (full_name, role) values ('[MÔ PHỎNG] Nhân viên B', 'staff') returning id into v_b;

  insert into ingredients (name, group_name, unit, importance) values ('Sữa [MP]', 'sữa', 'ml', 'important') returning id into v_milk;
  insert into ingredients (name, group_name, unit, importance) values ('Trà [MP]', 'trà', 'ml', 'important') returning id into v_tea;
  insert into ingredients (name, group_name, unit, importance) values ('Cà phê [MP]', 'cà phê', 'g', 'important') returning id into v_coffee;
  insert into ingredients (name, group_name, unit, importance) values ('Trân châu [MP]', 'topping', 'g', 'important') returning id into v_pearl;
  insert into ingredients (name, group_name, unit, importance) values ('Đường [MP]', 'gia vị', 'g', 'normal') returning id into v_sugar;

  insert into menu_items (name, group_name) values ('Trà sữa [MP]', 'trà sữa'), ('Cà phê sữa [MP]', 'cà phê'), ('Cà phê đen [MP]', 'cà phê');
  insert into menu_sizes (item_id, size_name, price)
    select id, s.sz, s.pr from menu_items, (values ('M', 35000), ('L', 42000)) s(sz, pr) where name = 'Trà sữa [MP]';
  insert into menu_sizes (item_id, size_name, price) select id, 'M', 29000 from menu_items where name = 'Cà phê sữa [MP]';
  insert into menu_sizes (item_id, size_name, price) select id, 'M', 25000 from menu_items where name = 'Cà phê đen [MP]';
  select ms.id into v_ts_m from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Trà sữa [MP]' and ms.size_name = 'M';
  select ms.id into v_ts_l from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Trà sữa [MP]' and ms.size_name = 'L';
  select ms.id into v_cf_s from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Cà phê sữa [MP]';
  select ms.id into v_cf_b from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Cà phê đen [MP]';

  insert into recipe_lines (size_id, ingredient_id, qty) values
    (v_ts_m, v_milk, 50), (v_ts_m, v_tea, 150), (v_ts_m, v_sugar, 20), (v_ts_m, v_pearl, 50),
    (v_ts_l, v_milk, 70), (v_ts_l, v_tea, 200), (v_ts_l, v_sugar, 30), (v_ts_l, v_pearl, 70),
    (v_cf_s, v_milk, 30), (v_cf_s, v_coffee, 20), (v_cf_s, v_sugar, 15),
    (v_cf_b, v_coffee, 25), (v_cf_b, v_sugar, 10);

  insert into areas (name) values ('[MP] Tầng 1');
  insert into dining_tables (area_id, name) select a.id, 'Bàn ' || g from areas a, generate_series(1, 8) g where a.name = '[MP] Tầng 1';
  select array_agg(id) into v_tables from dining_tables;
  -- Trọng số món: trà sữa M bán nhiều nhất
  v_sizes := array[v_ts_m, v_ts_m, v_ts_m, v_ts_m, v_ts_l, v_ts_l, v_cf_s, v_cf_s, v_cf_s, v_cf_b];

  stock := jsonb_build_object(v_milk::text, 20000, v_tea::text, 30000, v_coffee::text, 6000, v_pearl::text, 10000, v_sugar::text, 20000);

  for d in 1..30 loop
    v_staff := case when d % 2 = 0 then v_a else v_b end;
    v_open_ts  := ((day0 + d)::timestamp + time '07:00') at time zone 'Asia/Ho_Chi_Minh';
    v_close_ts := ((day0 + d)::timestamp + time '22:10') at time zone 'Asia/Ho_Chi_Minh';

    -- Kịch bản gian lận của ngày d
    v_scn := 'none'; v_hidden := 0;
    if d between 8 and 12  then v_scn := 'A_unbilled';       v_hidden := 12; v_staff := v_a; end if;
    if d between 15 and 16 then v_scn := 'D_small_unbilled'; v_hidden := 3;  v_staff := v_a; end if;
    if d between 19 and 21 then v_scn := 'B_overpour';       v_staff := v_b; end if;
    if d = 26              then v_scn := 'C_theft';          v_staff := v_b; end if;

    insert into shifts (opened_by, opened_at, closed_by, closed_at, opening_cash, closing_cash, status)
    values (v_staff, v_open_ts, v_staff, v_close_ts, 500000, 500000, 'closed') returning id into v_shift;
    insert into sim_ground_truth (shift_id, day_no, scenario, hidden_cups, note)
    values (v_shift, d, v_scn, v_hidden, case v_scn
      when 'A_unbilled' then 'Làm và bán ' || v_hidden || ' ly trà sữa M không lên bill'
      when 'D_small_unbilled' then 'Làm và bán 3 ly/ngày không lên bill (nhỏ, dưới ngưỡng)'
      when 'B_overpour' then 'Pha dư sữa 20%'
      when 'C_theft' then 'Mất 3000 g trân châu' else null end);

    -- Bills: 1-3 dòng mỗi bill, hầu hết mỗi dòng 1 ly
    v_n_bills := 85 + floor(random() * 50)::int + case when extract(dow from day0 + d) in (0, 6) then 25 else 0 end;
    create temp table tmp_bills on commit drop as
      select g as n, (random() < 0.7) as dine_in,
             v_open_ts + make_interval(mins => 15 + floor(random() * 780)::int) as opened_at
        from generate_series(1, v_n_bills) g;
    create temp table tmp_ids (id uuid, opened_at timestamptz) on commit drop;
    with ins as (
      insert into bills (shift_id, table_id, bill_type, guests, status, opened_by, opened_at, paid_by, paid_at, payment_method, total_amount)
      select v_shift,
             case when t.dine_in then v_tables[1 + floor(random() * cardinality(v_tables))::int] end,
             case when t.dine_in then 'dine_in' else 'take_away' end,
             case when t.dine_in then 1 + floor(random() * 4)::int end,
             'paid', v_staff, t.opened_at, v_staff, t.opened_at + interval '6 minutes',
             case when random() < 0.7 then 'cash' else 'transfer' end, 0
        from tmp_bills t
      returning id, opened_at)
    insert into tmp_ids select * from ins;

    -- Mỗi dòng chọn món ngẫu nhiên RIÊNG (random() đặt ở danh sách cột để chạy cho từng dòng)
    create temp table tmp_lines on commit drop as
      select i.id as bill_id, i.opened_at, s.k,
             v_sizes[1 + floor(random() * cardinality(v_sizes))::int] as sid,
             (1 + (random() < 0.15)::int) as qty, random() as rr
        from tmp_ids i cross join (values (1), (2), (3)) s(k);
    insert into bill_lines (bill_id, size_id, qty, unit_price, created_by, created_at)
    select l.bill_id, ms.id, l.qty, ms.price, v_staff, l.opened_at
      from tmp_lines l join menu_sizes ms on ms.id = l.sid
     where l.k = 1 or (l.k = 2 and l.rr < 0.5) or (l.k = 3 and l.rr < 0.2);

    update bills b set total_amount = x.t
      from (select bill_id, sum(qty * unit_price)::int as t from bill_lines
             where bill_id in (select id from tmp_ids) group by bill_id) x
     where b.id = x.bill_id;

    -- Sổ kho: bán (theo từng bill, giống hàm pay_bill)
    insert into stock_ledger (at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
    select b.paid_at, v_shift, r.ingredient_id, 'sale', -sum(l.qty * r.qty)::int, b.id, v_staff
      from bills b join bill_lines l on l.bill_id = b.id join recipe_lines r on r.size_id = l.size_id
     where b.shift_id = v_shift
     group by b.id, b.paid_at, r.ingredient_id;

    select coalesce(sum(total_amount), 0) into v_cash from bills where shift_id = v_shift;
    update shifts set closing_cash = 500000 + v_cash where id = v_shift;

    -- Kho từng nguyên liệu: nhập, hao hụt, thực dùng (có nhiễu + gian lận), đếm cuối ca
    for rec in select id, name from ingredients where name like '%[MP]' loop
      v_open := (stock ->> rec.id::text)::int;
      select coalesce(-sum(qty_delta), 0) into v_th from stock_ledger where shift_id = v_shift and ingredient_id = rec.id and kind = 'sale';

      -- Đếm đầu ca ngày 1 (các ngày sau lấy từ đếm cuối ca trước)
      if d = 1 then
        insert into stock_counts (shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
        values (v_shift, rec.id, 'open', v_open, v_staff, v_open_ts + interval '2 minutes');
      end if;

      -- Gian lận (chỉ ảnh hưởng tồn thật, KHÔNG có trong sổ kho)
      v_extra := 0;
      if v_scn in ('A_unbilled', 'D_small_unbilled') then
        v_extra := v_hidden * coalesce((select qty from recipe_lines where size_id = v_ts_m and ingredient_id = rec.id), 0);
      elsif v_scn = 'B_overpour' and rec.name = 'Sữa [MP]' then
        v_extra := round(v_th * 0.20)::int;
      elsif v_scn = 'C_theft' and rec.name = 'Trân châu [MP]' then
        v_extra := 3000;
      end if;

      -- Nhập hàng nếu tồn không đủ cho ngày hôm nay (theo bao/hộp)
      v_pack := case rec.name when 'Sữa [MP]' then 10000 when 'Trà [MP]' then 10000 when 'Cà phê [MP]' then 5000
                              when 'Trân châu [MP]' then 5000 else 10000 end;
      v_need := ceil(v_th * 1.3)::int + 1000 + v_extra;   -- chủ không biết có gian lận; kho luôn đủ để lấy
      v_purch := 0;
      if v_open < v_need then
        v_purch := ceil((v_need - v_open)::numeric / v_pack)::int * v_pack;
        insert into purchases (shift_id, ingredient_id, qty, entered_by, entered_at)
        values (v_shift, rec.id, v_purch, v_staff, v_open_ts + interval '30 minutes');
        insert into stock_ledger (at, shift_id, ingredient_id, kind, qty_delta, created_by)
        values (v_open_ts + interval '30 minutes', v_shift, rec.id, 'purchase', v_purch, v_staff);
      end if;

      -- Hao hụt có lý do: đôi khi đổ sữa
      v_waste := 0;
      if rec.name = 'Sữa [MP]' and random() < 0.25 then
        v_waste := 100 + floor(random() * 200)::int;
        insert into waste_logs (shift_id, ingredient_id, qty, reason, entered_by, entered_at)
        values (v_shift, rec.id, v_waste, 'Đổ ly làm sai', v_staff, v_open_ts + interval '5 hours');
        insert into stock_ledger (at, shift_id, ingredient_id, kind, qty_delta, created_by)
        values (v_open_ts + interval '5 hours', v_shift, rec.id, 'waste', -v_waste, v_staff);
      end if;

      -- Nhiễu pha chế bình thường ~ ±1,2% (tổng 3 số ngẫu nhiên)
      v_noise := (random() + random() + random() - 1.5) * 0.025;
      v_use := round(v_th * (1 + v_noise))::int + v_waste + v_extra;
      v_close_true := greatest(v_open + v_purch - v_use, 0);
      stock := jsonb_set(stock, array[rec.id::text], to_jsonb(v_close_true));

      -- Đếm cuối ca có sai số đo ±30
      v_cnt := greatest(v_close_true + floor(random() * 61)::int - 30, 0);
      insert into stock_counts (shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
      values (v_shift, rec.id, 'close', v_cnt, v_staff, v_close_ts - interval '5 minutes');
      -- Đồng bộ tồn đầu ngày sau với số đếm (sai số đo sẽ làm nhiễu nhẹ ở ca sau)
    end loop;

    drop table tmp_bills; drop table tmp_ids; drop table tmp_lines;
  end loop;
end $sim$;
