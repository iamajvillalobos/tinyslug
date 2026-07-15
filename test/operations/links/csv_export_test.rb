require "test_helper"

module Links
  class CsvExportTest < ActiveSupport::TestCase
    test "quotes special characters and neutralizes spreadsheet formulas" do
      link = links(:alice_docs)
      link.name = "=SUM(1,2)\n\"quoted\""

      csv = Links::CsvExport.call([ link ])

      assert_includes csv, %Q("'=SUM(1,2)\n""quoted""")
      assert_includes csv, %Q("#{link.destination_url}")
      assert csv.end_with?("\r\n")
    end
  end
end
