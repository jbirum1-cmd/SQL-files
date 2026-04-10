select
identifier,
california_proposition_65_warning_message
from pim.AllProductsTable
where california_proposition_65_warning_message is not null

select
identifier,
california_proposition_65_warning_message
from pim.AllProductsTable
where identifier = '339440'

