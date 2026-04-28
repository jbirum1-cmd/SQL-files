SELECT TOP (1000) *
FROM NaturalOrder.syn_process p
left join NaturalOrder.syn_process_result pr on pr.process_id = p.process_id
where process_type_id = 910
order by p.process_id desc 