with before as materialized (
  select id,housing_tags from public.map_places where category='home'
), changed as (
  update public.map_places p
  set housing_tags=case
    when '반려견'=any(coalesce(p.housing_tags,'{}'::text[]))
      then array_remove(coalesce(p.housing_tags,'{}'::text[]),'반려견 불가능')
    else array_append(array_remove(coalesce(p.housing_tags,'{}'::text[]),'반려견 불가능'),'반려견')
  end
  where p.category='home' and (
    not ('반려견'=any(coalesce(p.housing_tags,'{}'::text[])))
    or '반려견 불가능'=any(coalesce(p.housing_tags,'{}'::text[]))
  )
  returning p.id,p.housing_tags
)
select count(changed.id) as updated_homes,
bool_and(array_remove(coalesce(before.housing_tags,'{}'::text[]),'반려견 불가능') <@ coalesce(changed.housing_tags,before.housing_tags,'{}'::text[])) as existing_tags_preserved
from before left join changed using(id);
