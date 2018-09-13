# By using jbuilder on an enumerator, we reduce memory footprint (vs. to_a)
json.rows { json.array!(@discovery_report.each_row) }
json.summary @discovery_report.summary
