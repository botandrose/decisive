require "fileutils"
require "./spec/support/xls_hasher"

RSpec.describe Decisive do
  before { Decisive::TemplateHandler.register }

  Record = Struct.new(:a, :b, :c)

  before { stub_const "Rails", double(env: double(test?: false)) }

  let(:response) { double(headers: {}, stream: double) }
  let(:controller) { double }

  context "#xls" do
    context "with worksheets specified in template" do
      before do
        @records = [
          Record.new(1,2,3),
          Record.new(4,5,6),
          Record.new(7,8,9),
        ]
      end

      it "works without yielding records" do
        template = Struct.new(:source).new <<~DECISIVE
          records = @records
          xls filename: "test.xls" do
            worksheet records, name: "Ones" do
              column "A"
              column "Badgers", :b
              column "C"
              column "D", "D"
            end
            worksheet records, name: "Teens" do
              column("A") { |record| record.a + 10 }
              column("Badgers") { |record| record.b + 10 }
              column("C") { |record| record.c + 10 }
              column "D", "D"
            end
          end
        DECISIVE

        FileUtils.mkdir_p "tmp"
        path = "tmp/result.xls"
        result = eval(Decisive::TemplateHandler.call(template))
        File.open(path, "wb") { |io| io.write(result) }

        expect(XLSHasher.new(path).to_hash).to eq({
          "Ones" => [
            ["A","Badgers","C","D"],
            ["1","2","3","D"],
            ["4","5","6","D"],
            ["7","8","9","D"],
          ],
          "Teens" => [
            ["A","Badgers","C","D"],
            ["11","12","13","D"],
            ["14","15","16","D"],
            ["17","18","19","D"],
          ],
        })

        expect(response.headers).to eq({
          "Content-Disposition" => %(attachment; filename="test.xls"),
          "Content-Type" => "application/vnd.ms-excel",
          "Content-Transfer-Encoding" => "binary",
        })
      end

      context "with repeating column names" do
        xit "can handle them" do
          template = Struct.new(:source).new <<~DECISIVE
            xls @worksheets, filename: "test.xls" do
              column "A"
              column "A", :b
              column "A", :c
              column "D", "D"
            end
          DECISIVE

          FileUtils.mkdir_p "tmp"
          path = "tmp/result.xls"
          result = eval(Decisive::TemplateHandler.call(template))
          File.open(path, "wb") { |io| io.write(result) }

          expect(XLSHasher.new(path).to_hash).to eq({
            "Ones" => [
              ["A","A","A","D"],
              ["1","2","3","D"],
              ["4","5","6","D"],
              ["7","8","9","D"],
            ],
            "Teens" => [
              ["A","A","A","D"],
              ["11","12","13","D"],
              ["14","15","16","D"],
              ["17","18","19","D"],
            ],
          })

          expect(response.headers).to eq({
            "Content-Disposition" => %(attachment; filename="test.xls"),
            "Content-Type" => "application/vnd.ms-excel",
            "Content-Transfer-Encoding" => "binary",
          })
        end
      end
    end

    context "with illegal worksheet names" do
      it "deals with them" do
        @worksheets = {
          "Illegal[chars]*?:\t\n\r/\\" => [
            Record.new(1,2,3),
          ],
          "'No single quote's on ends'" => [
            Record.new(4,5,6),
          ],
          "Worksheet names cannot be longer than thirty-one characters" => [
            Record.new(7,8,9),
          ],
        }

        template = Struct.new(:source).new <<~DECISIVE
          xls @worksheets, filename: "test.xls" do
            column "A"
            column "B"
            column "C"
          end
        DECISIVE

        FileUtils.mkdir_p "tmp"
        path = "tmp/result.xls"
        result = eval(Decisive::TemplateHandler.call(template))
        File.open(path, "wb") { |io| io.write(result) }

        expect(XLSHasher.new(path).to_hash).to eq({
          "Illegal chars" => [
            ["A","B","C"],
            ["1","2","3"],
          ],
          "No single quote's on ends" => [
            ["A","B","C"],
            ["4","5","6"],
          ],
          "Worksheet names cannot be longe" => [
            ["A","B","C"],
            ["7","8","9"],
          ],
        })

        expect(response.headers).to eq({
          "Content-Disposition" => %(attachment; filename="test.xls"),
          "Content-Type" => "application/vnd.ms-excel",
          "Content-Transfer-Encoding" => "binary",
        })
      end
    end

    context "with worksheets specified implicitly in hash" do
      before do
        @worksheets = {
          "Ones" => [
            Record.new(1,2,3),
            Record.new(4,5,6),
            Record.new(7,8,9),
          ],
          "Teens" => [
            Record.new(11,12,13),
            Record.new(14,15,16),
            Record.new(17,18,19),
          ],
        }
      end

      it "works without yielding records" do
        template = Struct.new(:source).new <<~DECISIVE
          xls @worksheets, filename: "test.xls" do
            column "A"
            column "Badgers", :b
            column "C"
            column "D", "D"
          end
        DECISIVE

        FileUtils.mkdir_p "tmp"
        path = "tmp/result.xls"
        result = eval(Decisive::TemplateHandler.call(template))
        File.open(path, "wb") { |io| io.write(result) }

        expect(XLSHasher.new(path).to_hash).to eq({
          "Ones" => [
            ["A","Badgers","C","D"],
            ["1","2","3","D"],
            ["4","5","6","D"],
            ["7","8","9","D"],
          ],
          "Teens" => [
            ["A","Badgers","C","D"],
            ["11","12","13","D"],
            ["14","15","16","D"],
            ["17","18","19","D"],
          ],
        })

        expect(response.headers).to eq({
          "Content-Disposition" => %(attachment; filename="test.xls"),
          "Content-Type" => "application/vnd.ms-excel",
          "Content-Transfer-Encoding" => "binary",
        })
      end

      context "with repeating column names" do
        xit "can handle them" do
          template = Struct.new(:source).new <<~DECISIVE
            xls @worksheets, filename: "test.xls" do
              column "A"
              column "A", :b
              column "A", :c
              column "D", "D"
            end
          DECISIVE

          FileUtils.mkdir_p "tmp"
          path = "tmp/result.xls"
          result = eval(Decisive::TemplateHandler.call(template))
          File.open(path, "wb") { |io| io.write(result) }

          expect(XLSHasher.new(path).to_hash).to eq({
            "Ones" => [
              ["A","A","A","D"],
              ["1","2","3","D"],
              ["4","5","6","D"],
              ["7","8","9","D"],
            ],
            "Teens" => [
              ["A","A","A","D"],
              ["11","12","13","D"],
              ["14","15","16","D"],
              ["17","18","19","D"],
            ],
          })

          expect(response.headers).to eq({
            "Content-Disposition" => %(attachment; filename="test.xls"),
            "Content-Type" => "application/vnd.ms-excel",
            "Content-Transfer-Encoding" => "binary",
          })
        end
      end
    end

    context "with illegal worksheet names" do
      it "deals with them" do
        @worksheets = {
          "Illegal[chars]*?:\t\n\r/\\" => [
            Record.new(1,2,3),
          ],
          "'No single quote's on ends'" => [
            Record.new(4,5,6),
          ],
          "Worksheet names cannot be longer than thirty-one characters" => [
            Record.new(7,8,9),
          ],
        }

        template = Struct.new(:source).new <<~DECISIVE
          xls @worksheets, filename: "test.xls" do
            column "A"
            column "B"
            column "C"
          end
        DECISIVE

        FileUtils.mkdir_p "tmp"
        path = "tmp/result.xls"
        result = eval(Decisive::TemplateHandler.call(template))
        File.open(path, "wb") { |io| io.write(result) }

        expect(XLSHasher.new(path).to_hash).to eq({
          "Illegal chars" => [
            ["A","B","C"],
            ["1","2","3"],
          ],
          "No single quote's on ends" => [
            ["A","B","C"],
            ["4","5","6"],
          ],
          "Worksheet names cannot be longe" => [
            ["A","B","C"],
            ["7","8","9"],
          ],
        })

        expect(response.headers).to eq({
          "Content-Disposition" => %(attachment; filename="test.xls"),
          "Content-Type" => "application/vnd.ms-excel",
          "Content-Transfer-Encoding" => "binary",
        })
      end
    end
  end
end
