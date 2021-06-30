#!/bin/bash

APP=gmall
# 如果是输入的日期按照取输入日期；如果没输入日期取当前时间的前一天
if [ -n "$2" ] ;then
    do_date=$2
else 
    do_date=`date -d "-1 day" +%F`
fi

dws_visitor_action_daycount="insert overwrite table ${APP}.dws_visitor_action_daycount partition(dt='$do_date')
select
    t1.mid_id,
    t1.brand,
    t1.model,
    t1.is_new,
    t1.channel,
    t1.os,
    t1.area_code,
    t1.version_code,
    t1.visit_count,
    t3.page_stats
from
(
    select
        mid_id,
        brand,
        model,
        if(array_contains(collect_set(is_new),'0'),'0','1') is_new,--ods_page_log中，同一天内，同一设备的is_new字段，可能全部为1，可能全部为0，也可能部分为0，部分为1(卸载重装),故做该处理
        collect_set(channel) channel,
        collect_set(os) os,
        collect_set(area_code) area_code,
        collect_set(version_code) version_code,
        sum(if(last_page_id is null,1,0)) visit_count
    from ${APP}.dwd_page_log
    where dt='$do_date'
    and last_page_id is null
    group by mid_id,model,brand
)t1
join
(
    select
        mid_id,
        brand,
        model,
        collect_set(named_struct('page_id',page_id,'page_count',page_count,'during_time',during_time)) page_stats
    from
    (
        select
            mid_id,
            brand,
            model,
            page_id,
            count(*) page_count,
            sum(during_time) during_time
        from ${APP}.dwd_page_log
        where dt='$do_date'
        group by mid_id,model,brand,page_id
    )t2
    group by mid_id,model,brand
)t3
on t1.mid_id=t3.mid_id
and t1.brand=t3.brand
and t1.model=t3.model;"

dws_user_action_daycount="
with
tmp_login as
(
    select
        user_id,
        count(*) login_count
    from ${APP}.dwd_page_log
    where dt='$do_date'
    and user_id is not null
    and last_page_id is null
    group by user_id
),
tmp_cf as
(
    select
        user_id,
        sum(if(action_id='cart_add',1,0)) cart_count,
        sum(if(action_id='favor_add',1,0)) favor_count
    from ${APP}.dwd_action_log
    where dt='$do_date'
    and user_id is not null
    and action_id in ('cart_add','favor_add')
    group by user_id
),
tmp_order as
(
    select
        user_id,
        count(*) order_count,
        sum(if(activity_reduce_amount>0,1,0)) order_activity_count,
        sum(if(coupon_reduce_amount>0,1,0)) order_coupon_count,
        sum(activity_reduce_amount) order_activity_reduce_amount,
        sum(coupon_reduce_amount) order_coupon_reduce_amount,
        sum(original_amount) order_original_amount,
        sum(final_amount) order_final_amount
    from ${APP}.dwd_order_info
    where (dt='$do_date'
    or dt='9999-99-99')
    and date_format(create_time,'yyyy-MM-dd')='$do_date'
    group by user_id
),
tmp_pay as
(
    select
        user_id,
        count(*) payment_count,
        sum(payment_amount) payment_amount
    from ${APP}.dwd_payment_info
    where dt='$do_date'
    group by user_id
),
tmp_ri as
(
    select
        user_id,
        count(*) refund_order_count,
        sum(refund_num) refund_order_num,
        sum(refund_amount) refund_order_amount
    from ${APP}.dwd_order_refund_info
    where dt='$do_date'
    group by user_id
),
tmp_rp as
(
    select
        rp.user_id,
        count(*) refund_payment_count,
        sum(ri.refund_num) refund_payment_num,
        sum(rp.refund_amount) refund_payment_amount
    from
    (
        select
            user_id,
            order_id,
            sku_id,
            refund_amount
        from ${APP}.dwd_refund_payment
        where dt='$do_date'
    )rp
    left join
    (
        select
            user_id,
            order_id,
            sku_id,
            refund_num
        from ${APP}.dwd_order_refund_info
        where dt>=date_add('$do_date',-15)
    )ri
    on rp.order_id=ri.order_id
    and rp.sku_id=rp.sku_id
    group by rp.user_id
),
tmp_coupon as
(
    select
        user_id,
        sum(if(date_format(get_time,'yyyy-MM-dd')='$do_date',1,0)) coupon_get_count,
        sum(if(date_format(using_time,'yyyy-MM-dd')='$do_date',1,0)) coupon_using_count,
        sum(if(date_format(used_time,'yyyy-MM-dd')='$do_date',1,0)) coupon_used_count
    from ${APP}.dwd_coupon_use
    where (dt='$do_date' or dt='9999-99-99')
    and (date_format(get_time, 'yyyy-MM-dd') = '$do_date'
    or date_format(using_time,'yyyy-MM-dd')='$do_date'
    or date_format(used_time,'yyyy-MM-dd')='$do_date')
    group by user_id
),
tmp_comment as
(
    select
        user_id,
        sum(if(appraise='1201',1,0)) appraise_good_count,
        sum(if(appraise='1202',1,0)) appraise_mid_count,
        sum(if(appraise='1203',1,0)) appraise_bad_count,
        sum(if(appraise='1204',1,0)) appraise_default_count
    from ${APP}.dwd_comment_info
    where dt='$do_date'
    group by user_id
),
tmp_od as
(
    select
        user_id,
        collect_set(named_struct('sku_id',sku_id,'sku_num',sku_num,'order_count',order_count,'activity_reduce_amount',activity_reduce_amount,'coupon_reduce_amount',coupon_reduce_amount,'original_amount',original_amount,'final_amount',final_amount)) order_detail_stats
    from
    (
        select
            user_id,
            sku_id,
            sum(sku_num) sku_num,
            count(*) order_count,
            cast(sum(split_activity_amount) as decimal(16,2)) activity_reduce_amount,
            cast(sum(split_coupon_amount) as decimal(16,2)) coupon_reduce_amount,
            cast(sum(original_amount) as decimal(16,2)) original_amount,
            cast(sum(split_final_amount) as decimal(16,2)) final_amount
        from ${APP}.dwd_order_detail
        where dt='$do_date'
        group by user_id,sku_id
    )t1
    group by user_id
)
insert overwrite table ${APP}.dws_user_action_daycount partition(dt='$do_date')
select
    coalesce(tmp_login.user_id,tmp_cf.user_id,tmp_order.user_id,tmp_pay.user_id,tmp_ri.user_id,tmp_rp.user_id,tmp_comment.user_id,tmp_coupon.user_id,tmp_od.user_id),
    nvl(login_count,0),
    nvl(cart_count,0),
    nvl(favor_count,0),
    nvl(order_count,0),
    nvl(order_activity_count,0),
    nvl(order_activity_reduce_amount,0),
    nvl(order_coupon_count,0),
    nvl(order_coupon_reduce_amount,0),
    nvl(order_original_amount,0),
    nvl(order_final_amount,0),
    nvl(payment_count,0),
    nvl(payment_amount,0),
    nvl(refund_order_count,0),
    nvl(refund_order_num,0),
    nvl(refund_order_amount,0),
    nvl(refund_payment_count,0),
    nvl(refund_payment_num,0),
    nvl(refund_payment_amount,0),
    nvl(coupon_get_count,0),
    nvl(coupon_using_count,0),
    nvl(coupon_used_count,0),
    nvl(appraise_good_count,0),
    nvl(appraise_mid_count,0),
    nvl(appraise_bad_count,0),
    nvl(appraise_default_count,0),
    order_detail_stats
from tmp_login
full outer join tmp_cf on tmp_login.user_id=tmp_cf.user_id
full outer join tmp_order on coalesce(tmp_login.user_id,tmp_cf.user_id)=tmp_order.user_id
full outer join tmp_pay on coalesce(tmp_login.user_id,tmp_cf.user_id,tmp_order.user_id)=tmp_pay.user_id
full outer join tmp_ri on coalesce(tmp_login.user_id,tmp_cf.user_id,tmp_order.user_id,tmp_pay.user_id)=tmp_ri.user_id
full outer join tmp_rp on coalesce(tmp_login.user_id,tmp_cf.user_id,tmp_order.user_id,tmp_pay.user_id,tmp_ri.user_id)=tmp_rp.user_id
full outer join tmp_comment on coalesce(tmp_login.user_id,tmp_cf.user_id,tmp_order.user_id,tmp_pay.user_id,tmp_ri.user_id,tmp_rp.user_id)=tmp_comment.user_id
full outer join tmp_coupon on coalesce(tmp_login.user_id,tmp_cf.user_id,tmp_order.user_id,tmp_pay.user_id,tmp_ri.user_id,tmp_rp.user_id,tmp_comment.user_id)=tmp_coupon.user_id
full outer join tmp_od on coalesce(tmp_login.user_id,tmp_cf.user_id,tmp_order.user_id,tmp_pay.user_id,tmp_ri.user_id,tmp_rp.user_id,tmp_comment.user_id,tmp_coupon.user_id)=tmp_od.user_id;
"


dws_activity_info_daycount="
with
tmp_order as
(
    select
        activity_rule_id,
        activity_id,
        count(*) order_count,
        sum(split_activity_amount) order_reduce_amount,
        sum(original_amount) order_original_amount,
        sum(split_final_amount) order_final_amount
    from ${APP}.dwd_order_detail
    where dt='$do_date'
    and activity_id is not null
    group by activity_rule_id,activity_id
),
tmp_pay as
(
    select
        activity_rule_id,
        activity_id,
        count(*) payment_count,
        sum(split_activity_amount) payment_reduce_amount,
        sum(split_final_amount) payment_amount
    from ${APP}.dwd_order_detail
    where (dt='$do_date'
    or dt=date_add('$do_date',-1))
    and activity_id is not null
    and order_id in
    (
        select order_id from ${APP}.dwd_payment_info where dt='$do_date'
    )
    group by activity_rule_id,activity_id
)
insert overwrite table ${APP}.dws_activity_info_daycount partition(dt='$do_date')
select
    activity_rule_id,
    activity_id,
    sum(order_count),
    sum(order_reduce_amount),
    sum(order_original_amount),
    sum(order_final_amount),
    sum(payment_count),
    sum(payment_reduce_amount),
    sum(payment_amount)
from
(
    select
        activity_rule_id,
        activity_id,
        order_count,
        order_reduce_amount,
        order_original_amount,
        order_final_amount,
        0 payment_count,
        0 payment_reduce_amount,
        0 payment_amount
    from tmp_order
    union all
    select
        activity_rule_id,
        activity_id,
        0 order_count,
        0 order_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        payment_count,
        payment_reduce_amount,
        payment_amount
    from tmp_pay
)t1
group by activity_rule_id,activity_id;"


dws_sku_action_daycount="
with
tmp_order as
(
    select
        sku_id,
        count(*) order_count,
        sum(sku_num) order_num,
        sum(if(split_activity_amount>0,1,0)) order_activity_count,
        sum(if(split_coupon_amount>0,1,0)) order_coupon_count,
        sum(split_activity_amount) order_activity_reduce_amount,
        sum(split_coupon_amount) order_coupon_reduce_amount,
        sum(original_amount) order_original_amount,
        sum(split_final_amount) order_final_amount
    from ${APP}.dwd_order_detail
    where dt='$do_date'
    group by sku_id
),
tmp_pay as
(
    select
        sku_id,
        count(*) payment_count,
        sum(sku_num) payment_num,
        sum(split_final_amount) payment_amount
    from ${APP}.dwd_order_detail
    where (dt='$do_date'
    or dt=date_add('$do_date',-1))
    and order_id in
    (
        select order_id from ${APP}.dwd_payment_info where dt='$do_date'
    )
    group by sku_id
),
tmp_ri as
(
    select
        sku_id,
        count(*) refund_order_count,
        sum(refund_num) refund_order_num,
        sum(refund_amount) refund_order_amount
    from ${APP}.dwd_order_refund_info
    where dt='$do_date'
    group by sku_id
),
tmp_rp as
(
    select
        rp.sku_id,
        count(*) refund_payment_count,
        sum(ri.refund_num) refund_payment_num,
        sum(refund_amount) refund_payment_amount
    from
    (
        select
            order_id,
            sku_id,
            refund_amount
        from ${APP}.dwd_refund_payment
        where dt='$do_date'
    )rp
    left join
    (
        select
            order_id,
            sku_id,
            refund_num
        from ${APP}.dwd_order_refund_info
        where dt>=date_add('$do_date',-15)
    )ri
    on rp.order_id=ri.order_id
    and rp.sku_id=ri.sku_id
    group by rp.sku_id
),
tmp_cf as
(
    select
        item sku_id,
        sum(if(action_id='cart_add',1,0)) cart_count,
        sum(if(action_id='favor_add',1,0)) favor_count
    from ${APP}.dwd_action_log
    where dt='$do_date'
    and action_id in ('cart_add','favor_add')
    group by item
),
tmp_comment as
(
    select
        sku_id,
        sum(if(appraise='1201',1,0)) appraise_good_count,
        sum(if(appraise='1202',1,0)) appraise_mid_count,
        sum(if(appraise='1203',1,0)) appraise_bad_count,
        sum(if(appraise='1204',1,0)) appraise_default_count
    from ${APP}.dwd_comment_info
    where dt='$do_date'
    group by sku_id
)
insert overwrite table ${APP}.dws_sku_action_daycount partition(dt='$do_date')
select
    sku_id,
    sum(order_count),
    sum(order_num),
    sum(order_activity_count),
    sum(order_coupon_count),
    sum(order_activity_reduce_amount),
    sum(order_coupon_reduce_amount),
    sum(order_original_amount),
    sum(order_final_amount),
    sum(payment_count),
    sum(payment_num),
    sum(payment_amount),
    sum(refund_order_count),
    sum(refund_order_num),
    sum(refund_order_amount),
    sum(refund_payment_count),
    sum(refund_payment_num),
    sum(refund_payment_amount),
    sum(cart_count),
    sum(favor_count),
    sum(appraise_good_count),
    sum(appraise_mid_count),
    sum(appraise_bad_count),
    sum(appraise_default_count)
from
(
    select
        sku_id,
        order_count,
        order_num,
        order_activity_count,
        order_coupon_count,
        order_activity_reduce_amount,
        order_coupon_reduce_amount,
        order_original_amount,
        order_final_amount,
        0 payment_count,
        0 payment_num,
        0 payment_amount,
        0 refund_order_count,
        0 refund_order_num,
        0 refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_num,
        0 refund_payment_amount,
        0 cart_count,
        0 favor_count,
        0 appraise_good_count,
        0 appraise_mid_count,
        0 appraise_bad_count,
        0 appraise_default_count
    from tmp_order
    union all
    select
        sku_id,
        0 order_count,
        0 order_num,
        0 order_activity_count,
        0 order_coupon_count,
        0 order_activity_reduce_amount,
        0 order_coupon_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        payment_count,
        payment_num,
        payment_amount,
        0 refund_order_count,
        0 refund_order_num,
        0 refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_num,
        0 refund_payment_amount,
        0 cart_count,
        0 favor_count,
        0 appraise_good_count,
        0 appraise_mid_count,
        0 appraise_bad_count,
        0 appraise_default_count
    from tmp_pay
    union all
    select
        sku_id,
        0 order_count,
        0 order_num,
        0 order_activity_count,
        0 order_coupon_count,
        0 order_activity_reduce_amount,
        0 order_coupon_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        0 payment_num,
        0 payment_amount,
        refund_order_count,
        refund_order_num,
        refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_num,
        0 refund_payment_amount,
        0 cart_count,
        0 favor_count,
        0 appraise_good_count,
        0 appraise_mid_count,
        0 appraise_bad_count,
        0 appraise_default_count
    from tmp_ri
    union all
    select
        sku_id,
        0 order_count,
        0 order_num,
        0 order_activity_count,
        0 order_coupon_count,
        0 order_activity_reduce_amount,
        0 order_coupon_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        0 payment_num,
        0 payment_amount,
        0 refund_order_count,
        0 refund_order_num,
        0 refund_order_amount,
        refund_payment_count,
        refund_payment_num,
        refund_payment_amount,
        0 cart_count,
        0 favor_count,
        0 appraise_good_count,
        0 appraise_mid_count,
        0 appraise_bad_count,
        0 appraise_default_count
    from tmp_rp
    union all
    select
        sku_id,
        0 order_count,
        0 order_num,
        0 order_activity_count,
        0 order_coupon_count,
        0 order_activity_reduce_amount,
        0 order_coupon_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        0 payment_num,
        0 payment_amount,
        0 refund_order_count,
        0 refund_order_num,
        0 refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_num,
        0 refund_payment_amount,
        cart_count,
        favor_count,
        0 appraise_good_count,
        0 appraise_mid_count,
        0 appraise_bad_count,
        0 appraise_default_count
    from tmp_cf
    union all
    select
        sku_id,
        0 order_count,
        0 order_num,
        0 order_activity_count,
        0 order_coupon_count,
        0 order_activity_reduce_amount,
        0 order_coupon_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        0 payment_num,
        0 payment_amount,
        0 refund_order_count,
        0 refund_order_num,
        0 refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_num,
        0 refund_payment_amount,
        0 cart_count,
        0 favor_count,
        appraise_good_count,
        appraise_mid_count,
        appraise_bad_count,
        appraise_default_count
    from tmp_comment
)t1
group by sku_id;"

dws_coupon_info_daycount="
with
tmp_cu as
(
    select
        coupon_id,
        sum(if(date_format(get_time,'yyyy-MM-dd')='$do_date',1,0)) get_count,
        sum(if(date_format(using_time,'yyyy-MM-dd')='$do_date',1,0)) order_count,
        sum(if(date_format(used_time,'yyyy-MM-dd')='$do_date',1,0)) payment_count,
        sum(if(date_format(expire_time,'yyyy-MM-dd')='$do_date',1,0)) expire_count
    from ${APP}.dwd_coupon_use
    where dt='9999-99-99'
    or dt='$do_date'
    group by coupon_id
),
tmp_order as
(
    select
        coupon_id,
        sum(split_coupon_amount) order_reduce_amount,
        sum(original_amount) order_original_amount,
        sum(split_final_amount) order_final_amount
    from ${APP}.dwd_order_detail
    where dt='$do_date'
    and coupon_id is not null
    group by coupon_id
),
tmp_pay as
(
    select
        coupon_id,
        sum(split_coupon_amount) payment_reduce_amount,
        sum(split_final_amount) payment_amount
    from ${APP}.dwd_order_detail
    where (dt='$do_date'
    or dt=date_add('$do_date',-1))
    and coupon_id is not null
    and order_id in
    (
        select order_id from ${APP}.dwd_payment_info where dt='$do_date'
    )
    group by coupon_id
)
insert overwrite table ${APP}.dws_coupon_info_daycount partition(dt='$do_date')
select
    coupon_id,
    sum(get_count),
    sum(order_count),
    sum(order_reduce_amount),
    sum(order_original_amount),
    sum(order_final_amount),
    sum(payment_count),
    sum(payment_reduce_amount),
    sum(payment_amount),
    sum(expire_count)
from
(
    select
        coupon_id,
        get_count,
        order_count,
        0 order_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        payment_count,
        0 payment_reduce_amount,
        0 payment_amount,
        expire_count
    from tmp_cu
    union all
    select
        coupon_id,
        0 get_count,
        0 order_count,
        order_reduce_amount,
        order_original_amount,
        order_final_amount,
        0 payment_count,
        0 payment_reduce_amount,
        0 payment_amount,
        0 expire_count
    from tmp_order
    union all
    select
        coupon_id,
        0 get_count,
        0 order_count,
        0 order_reduce_amount,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        payment_reduce_amount,
        payment_amount,
        0 expire_count
    from tmp_pay
)t1
group by coupon_id;"


dws_area_stats_daycount="
with
tmp_vu as
(
    select
        id province_id,
        visit_count,
        login_count,
        visitor_count,
        user_count
    from
    (
        select
            area_code,
            count(*) visit_count,--访客访问次数
            count(user_id) login_count,--用户访问次数,等价于sum(if(user_id is not null,1,0))
            count(distinct(mid_id)) visitor_count,--访客人数
            count(distinct(user_id)) user_count--用户人数
        from ${APP}.dwd_page_log
        where dt='$do_date'
        and last_page_id is null
        group by area_code
    )tmp
    left join ${APP}.dim_base_province area
    on tmp.area_code=area.area_code
),
tmp_order as
(
    select
        province_id,
        count(*) order_count,
        sum(original_amount) order_original_amount,
        sum(final_amount) order_final_amount
    from ${APP}.dwd_order_info
    where dt='$do_date'
    or dt='9999-99-99'
    and date_format(create_time,'yyyy-MM-dd')='$do_date'
    group by province_id
),
tmp_pay as
(
    select
        province_id,
        count(*) payment_count,
        sum(payment_amount) payment_amount
    from ${APP}.dwd_payment_info
    where dt='$do_date'
    group by province_id
),
tmp_ro as
(
    select
        province_id,
        count(*) refund_order_count,
        sum(refund_amount) refund_order_amount
    from ${APP}.dwd_order_refund_info
    where dt='$do_date'
    group by province_id
),
tmp_rp as
(
    select
        province_id,
        count(*) refund_payment_count,
        sum(refund_amount) refund_payment_amount
    from ${APP}.dwd_refund_payment
    where dt='$do_date'
    group by province_id
)
insert overwrite table ${APP}.dws_area_stats_daycount partition(dt='$do_date')
select
    province_id,
    sum(visit_count),
    sum(login_count),
    sum(visitor_count),
    sum(user_count),
    sum(order_count),
    sum(order_original_amount),
    sum(order_final_amount),
    sum(payment_count),
    sum(payment_amount),
    sum(refund_order_count),
    sum(refund_order_amount),
    sum(refund_payment_count),
    sum(refund_payment_amount)
from
(
    select
        province_id,
        visit_count,
        login_count,
        visitor_count,
        user_count,
        0 order_count,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        0 payment_amount,
        0 refund_order_count,
        0 refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_amount
    from tmp_vu
    union all
    select
        province_id,
        0 visit_count,
        0 login_count,
        0 visitor_count,
        0 user_count,
        order_count,
        order_original_amount,
        order_final_amount,
        0 payment_count,
        0 payment_amount,
        0 refund_order_count,
        0 refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_amount
    from tmp_order
    union all
    select
        province_id,
        0 visit_count,
        0 login_count,
        0 visitor_count,
        0 user_count,
        0 order_count,
        0 order_original_amount,
        0 order_final_amount,
        payment_count,
        payment_amount,
        0 refund_order_count,
        0 refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_amount
    from tmp_pay
    union all
    select
        province_id,
        0 visit_count,
        0 login_count,
        0 visitor_count,
        0 user_count,
        0 order_count,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        0 payment_amount,
        refund_order_count,
        refund_order_amount,
        0 refund_payment_count,
        0 refund_payment_amount
    from tmp_ro
    union all
    select
        province_id,
        0 visit_count,
        0 login_count,
        0 visitor_count,
        0 user_count,
        0 order_count,
        0 order_original_amount,
        0 order_final_amount,
        0 payment_count,
        0 payment_amount,
        0 refund_order_count,
        0 refund_order_amount,
        refund_payment_count,
        refund_payment_amount
    from tmp_rp
)t1
group by province_id;"

case $1 in
    "dws_visitor_action_daycount" )
        hive -e "$dws_visitor_action_daycount"
    ;;
    "dws_user_action_daycount" )
        hive -e "$dws_user_action_daycount"
    ;;
    "dws_activity_info_daycount" )
        hive -e "$dws_activity_info_daycount"
    ;;
    "dws_area_stats_daycount" )
        hive -e "$dws_area_stats_daycount"
    ;;
    "dws_sku_action_daycount" )
        hive -e "$dws_sku_action_daycount"
    ;;
    "dws_coupon_info_daycount" )
        hive -e "$dws_coupon_info_daycount"
    ;;
    "all" )
        hive -e "$dws_visitor_action_daycount$dws_user_action_daycount$dws_activity_info_daycount$dws_area_stats_daycount$dws_sku_action_daycount$dws_coupon_info_daycount"
    ;;
esac
