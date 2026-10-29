-- =====================================================================
-- Fore · 011_app_read_api.sql · API đọc cho app nhiều quán
-- Chạy SAU 010_current_shift.sql, MỘT lần trong SQL Editor. Chạy lại cũng an toàn.
--
-- Vì sao cần: các màn hình thiết kế (bản đồ bàn, đơn mang đi, đóng ca) cần dữ liệu mà bảng gốc không trả
-- trực tiếp hoặc trả không an toàn cho nhân viên:
--   · tên quán theo quán đang chọn                               -> shop_info()
--   · "Ca của An, mở lúc 8:02" (RLS chỉ cho nhân viên thấy tên mình) -> current_shift()  (KHÔNG trả tiền)
--   · số phần đang gọi trên từng bàn                            -> table_map()
--   · danh sách đơn mang đi chưa xong, cũ nhất ở trên           -> takeaway_orders()
--   · danh sách việc trước khi đóng ca (đếm mù: chỉ trả SỐ LƯỢNG, không trả số đo) -> shift_close_status()
--   · thực đơn, chi tiết bill, phiếu kiểm kê, danh mục nhập/hao hụt -> menu_for_sale(), bill_detail(), count_sheet(), ...
-- Mọi hàm đọc là security definer: app không phụ thuộc quyền đọc bảng, nên sau này siết quyền đọc của nhân viên
-- (đợt rà soát A1/A2) cũng không làm app hỏng. Không hàm nào trả công thức, tồn kho, ngưỡng cảnh báo hay tiền két.
--
-- Luồng tạo/chọn quán đã có trong 008_staff_setup.sql; migration này chỉ thêm API đọc cho app.
-- =====================================================================

-- ---------- Sắp xếp khu và bàn ----------
alter table areas         add column if not exists sort_order integer not null default 0;
alter table dining_tables add column if not exists sort_order integer not null default 0;

-- Hồ sơ quán theo quán đang chọn; giữ nguyên mô hình nhiều quán của dự án.
create or replace function shop_info()
returns table (shop_name text, shop_type text, serving_label text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query select sh.name, 'drink'::text, 'phần'::text from shops sh where sh.id = app_shop_id();
end $$;
-- Việc còn thiếu trước khi đóng ca. Chỉ trả SỐ LƯỢNG; không lộ nguyên liệu nào đã đếm bao nhiêu.
create or replace function shift_close_status()
returns table (open_bills integer, missing_counts integer)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  v_shift := _open_shift_id();
  return query select
    (select count(*)::integer from bills b where b.shift_id = v_shift and b.status = 'open'),
    (select count(*)::integer from ingredients i
      where i.active and i.shop_id = app_shop_id() and not i.weekly_check
        and not exists (select 1 from stock_counts c
                         where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = 'close'));
end $$;

-- Bản đồ bàn: mỗi bàn đang dùng được một bill (nếu có) kèm tổng số phần đang gọi.
create or replace function table_map()
returns table (area_id uuid, area_name text, table_id uuid, table_name text,
               bill_id uuid, bill_no bigint, portions integer, guests integer, bill_opened_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select a.id, a.name, t.id, t.name, b.id, b.bill_no, coalesce(l.portions, 0)::integer, b.guests, b.opened_at
      from dining_tables t
      join areas a on a.id = t.area_id
      left join bills b on b.table_id = t.id and b.status = 'open'
      left join lateral (select sum(bl.qty) as portions from bill_lines bl
                          where bl.bill_id = b.id and bl.voided_at is null) l on true
     where t.active and a.active and t.shop_id = app_shop_id() and a.shop_id = app_shop_id()
     order by a.sort_order, a.name, t.sort_order,
              nullif(left(regexp_replace(t.name, '\D', '', 'g'), 9), '')::integer nulls last, t.name;
end $$;

-- Đơn mang đi của ca đang mở mà chưa làm xong (đã thu tiền hay chưa đều hiện). Cũ nhất ở trên.
create or replace function takeaway_orders()
returns table (bill_id uuid, bill_no bigint, status text, opened_at timestamptz, portions integer, items text)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  select s.id into v_shift from shifts s where s.status = 'open' and s.shop_id = app_shop_id();
  return query
    select b.id, b.bill_no, b.status, b.opened_at,
           coalesce((select sum(bl.qty) from bill_lines bl where bl.bill_id = b.id and bl.voided_at is null), 0)::integer,
           coalesce((select string_agg(x.name, ', ' order by x.first_at)
                       from (select mi.name, min(bl.created_at) as first_at
                               from bill_lines bl
                               join menu_sizes ms on ms.id = bl.size_id
                               join menu_items mi on mi.id = ms.item_id
                              where bl.bill_id = b.id and bl.voided_at is null
                              group by mi.name) x), '')
      from bills b
     where b.shop_id = app_shop_id() and b.shift_id = v_shift and b.bill_type = 'take_away'
       and b.prep_done_at is null and b.status <> 'cancelled'
     order by b.opened_at, b.bill_no;
end $$;

-- Thực đơn đang bán (món và size đều đang bật). Không có công thức.
create or replace function menu_for_sale()
returns table (item_id uuid, item_name text, group_name text, size_id uuid, size_name text, price integer)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select mi.id, mi.name, mi.group_name, ms.id, ms.size_name, ms.price
      from menu_items mi join menu_sizes ms on ms.item_id = mi.id
     where mi.active and ms.active and mi.shop_id = app_shop_id() and ms.shop_id = app_shop_id()
     order by mi.group_name nulls last, mi.name, ms.price, ms.size_name;
end $$;

-- Chi tiết một bill (màn gọi món / thanh toán). Số tiền tính ở database, app chỉ hiển thị.
create or replace function bill_detail(p_bill uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_bill record; v_lines jsonb; v_sub bigint; v_payable bigint;
begin
  perform _require_staff();
  select b.id, b.bill_no, b.status, b.bill_type, b.table_id, b.guests, b.opened_at, b.discount, b.discount_reason,
         b.total_amount, b.payment_method, b.prep_done_at, t.name as table_name, a.name as area_name
    into v_bill
    from bills b
    left join dining_tables t on t.id = b.table_id
    left join areas a on a.id = t.area_id
   where b.id = p_bill and b.shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
                    'id', l.id, 'size_id', l.size_id, 'item_name', mi.name, 'size_name', ms.size_name,
                    'qty', l.qty, 'unit_price', l.unit_price, 'voided', l.voided_at is not null)
                  order by l.created_at, l.id), '[]'::jsonb),
         coalesce(sum(l.qty::bigint * l.unit_price) filter (where l.voided_at is null), 0)
    into v_lines, v_sub
    from bill_lines l
    join menu_sizes ms on ms.id = l.size_id
    join menu_items mi on mi.id = ms.item_id
   where l.bill_id = p_bill;

  v_payable := case when v_bill.status = 'open' then greatest(v_sub - v_bill.discount, 0)
                    else coalesce(v_bill.total_amount, 0) end;
  return jsonb_build_object(
    'id', v_bill.id, 'bill_no', v_bill.bill_no, 'status', v_bill.status, 'bill_type', v_bill.bill_type,
    'table_id', v_bill.table_id, 'table_name', v_bill.table_name, 'area_name', v_bill.area_name,
    'guests', v_bill.guests, 'opened_at', v_bill.opened_at, 'discount', v_bill.discount,
    'discount_reason', v_bill.discount_reason, 'payment_method', v_bill.payment_method,
    'prep_done', v_bill.prep_done_at is not null,
    'lines', v_lines, 'subtotal', v_sub, 'payable', v_payable);
end $$;

-- Phiếu kiểm kê: danh sách nguyên liệu cần đếm. ĐẾM MÙ: chỉ có cờ "đã đếm", KHÔNG có số đã nhập, số dự kiến hay tồn.
create or replace function count_sheet(p_kind text)
returns table (ingredient_id uuid, name text, unit text, importance text, weekly_check boolean, group_name text, counted boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  if p_kind is null or p_kind not in ('open', 'close') then raise exception 'KIND_INVALID'; end if;
  v_shift := _open_shift_id();
  return query
    select i.id, i.name, i.unit, i.importance, i.weekly_check, i.group_name,
           exists (select 1 from stock_counts c
                    where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = p_kind)
      from ingredients i
     where i.active and i.shop_id = app_shop_id()
     order by (i.importance = 'important') desc, i.weekly_check, i.group_name nulls last, i.name;
end $$;

-- Danh mục cho phiếu nhập hàng / ghi hao hụt.
create or replace function ingredient_list()
returns table (ingredient_id uuid, name text, unit text, importance text, group_name text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select i.id, i.name, i.unit, i.importance, i.group_name
      from ingredients i where i.active and i.shop_id = app_shop_id()
     order by i.group_name nulls last, i.name;
end $$;

create or replace function waste_type_list()
returns table (code text, label_vi text, requires_note boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select w.code, w.label_vi, w.requires_note from waste_types w where w.active and w.shop_id = app_shop_id() order by w.sort_order, w.label_vi;
end $$;

-- Các truy vấn có SECURITY DEFINER đều lọc theo quán đang chọn.
revoke all on function shop_info(), shift_close_status(), table_map(), takeaway_orders(),
  menu_for_sale(), bill_detail(uuid), count_sheet(text), ingredient_list(), waste_type_list()
  from public, anon;
grant execute on function shop_info(), shift_close_status(), table_map(), takeaway_orders(),
  menu_for_sale(), bill_detail(uuid), count_sheet(text), ingredient_list(), waste_type_list()
  to authenticated;
