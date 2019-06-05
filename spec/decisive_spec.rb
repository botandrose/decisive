RSpec.describe Decisive do
  before { Decisive::TemplateHandler.register }

  Record = Struct.new(:a, :b, :c)

  let(:response) { double(headers: {}, stream: double) }
  let(:controller) { double }

  context "#csv" do
    it "works with yielding records to #column" do
      allow(controller).to receive(:new_controller_thread).and_return(true)

      @records = [
        Record.new(1,2,3),
        Record.new(4,5,6),
        Record.new(7,8,9),
      ]

      template = Struct.new(:source).new <<~DECISIVE
        csv @records, filename: "test.csv" do
          column "A"
          column "Badgers", :b
          column "C"
          column "Sum" do |record| record.a + record.b + record.c; end
        end
      DECISIVE


      expect(response.stream).to receive(:write).with("A,Badgers,C,Sum\n")
      expect(response.stream).to receive(:write).with("1,2,3,6\n")
      expect(response.stream).to receive(:write).with("4,5,6,15\n")
      expect(response.stream).to receive(:write).with("7,8,9,24\n")
      expect(response.stream).to receive(:close)

      eval(Decisive::TemplateHandler.call(template))

      expect(response.headers).to eq({
        "Content-Disposition" => %(attachment; filename="test.csv"),
        "Content-Type" => "text/csv",
        "Content-Transfer-Encoding" => "binary",
      })
    end

    it "works without yielding records" do
      allow(controller).to receive(:new_controller_thread).and_return(true)

      @records = [
        Record.new(1,2,3),
        Record.new(4,5,6),
        Record.new(7,8,9),
      ]

      template = Struct.new(:source).new <<~DECISIVE
        csv @records, filename: "test.csv" do
          column "A"
          column "Badgers", :b
          column "C"
          column("D") { "D" }
        end
      DECISIVE

      expect(response.stream).to receive(:write).with("A,Badgers,C,D\n")
      expect(response.stream).to receive(:write).with("1,2,3,D\n")
      expect(response.stream).to receive(:write).with("4,5,6,D\n")
      expect(response.stream).to receive(:write).with("7,8,9,D\n")
      expect(response.stream).to receive(:close)

      eval(Decisive::TemplateHandler.call(template))

      expect(response.headers).to eq({
        "Content-Disposition" => %(attachment; filename="test.csv"),
        "Content-Type" => "text/csv",
        "Content-Transfer-Encoding" => "binary",
      })
    end

    it "raises an error when trying to yield a record to itself" do
      allow(controller).to receive(:new_controller_thread).and_return(true)

      @records = [
        Record.new(1,2,3),
        Record.new(4,5,6),
        Record.new(7,8,9),
      ]

      template = Struct.new(:source).new <<~DECISIVE
        csv @records, filename: "test.csv" do |record|
          column "A"
          column "Badgers", :b
          column "C"
          column "Sum" do
            record.a + record.b + record.c
          end
        end
      DECISIVE

      expect { eval(Decisive::TemplateHandler.call(template)) }.to raise_error(Decisive::StreamIncompatibleBlockArgumentError)
    end

    it "raises an error when trying to stream but controller doesnt support it" do
      @records = [
        Record.new(1,2,3),
        Record.new(4,5,6),
        Record.new(7,8,9),
      ]

      template = Struct.new(:source).new <<~DECISIVE
        csv @records, filename: "test.csv" do
          column "A"
          column "Badgers", :b
          column "C"
          column "Sum" do |record|
            record.a + record.b + record.c
          end
        end
      DECISIVE

      expect { eval(Decisive::TemplateHandler.call(template)) }.to raise_error(Decisive::StreamingNotEnabledByControllerError)
    end
  end

  context "#csv stream: false" do
    before do
      @records = [
        Record.new(1,2,3),
        Record.new(4,5,6),
        Record.new(7,8,9),
      ]
    end

    it "works with yielding records to itself" do
      template = Struct.new(:source).new <<~DECISIVE
        csv @records, filename: "test.csv", stream: false do |record|
          column "A"
          column "Badgers", :b
          column "C"
          column "Sum" do
            record.a + record.b + record.c
          end
        end
      DECISIVE

      result = eval(Decisive::TemplateHandler.call(template))

      expect(result).to eq <<~CSV
        A,Badgers,C,Sum
        1,2,3,6
        4,5,6,15
        7,8,9,24
      CSV

      expect(response.headers).to eq({
        "Content-Disposition" => %(attachment; filename="test.csv"),
        "Content-Type" => "text/csv",
        "Content-Transfer-Encoding" => "binary",
      })
    end

    it "works without yielding records" do
      @records = [
        Record.new(1,2,3),
        Record.new(4,5,6),
        Record.new(7,8,9),
      ]

      template = Struct.new(:source).new <<~DECISIVE
        csv @records, filename: "test.csv", stream: false do
          column "A"
          column "Badgers", :b
          column "C"
          column "D", "D"
        end
      DECISIVE

      result = eval(Decisive::TemplateHandler.call(template))

      expect(result).to eq <<~CSV
        A,Badgers,C,D
        1,2,3,D
        4,5,6,D
        7,8,9,D
      CSV

      expect(response.headers).to eq({
        "Content-Disposition" => %(attachment; filename="test.csv"),
        "Content-Type" => "text/csv",
        "Content-Transfer-Encoding" => "binary",
      })
    end
  end
end
