--search for JDSO skus already in Eagle
select top 100 * from sqleagle.hh.view_in_clone where in_location_codes = 'so' and in_manufacturer = 'deere'

