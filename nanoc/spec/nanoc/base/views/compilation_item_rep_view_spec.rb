# frozen_string_literal: true

require_relative 'support/item_rep_view_examples'

describe Nanoc::CompilationItemRepView do
  let(:expected_item_view_class) { Nanoc::CompilationItemView }

  it_behaves_like 'an item rep view'

  let(:view_context) do
    Nanoc::ViewContextForCompilation.new(
      reps:                Nanoc::Int::ItemRepRepo.new,
      items:               Nanoc::Int::ItemCollection.new(config),
      dependency_tracker:  dependency_tracker,
      compilation_context: compilation_context,
      snapshot_repo:       snapshot_repo,
    )
  end

  let(:compilation_context) { double(:compilation_context) }
  let(:snapshot_repo) { Nanoc::Int::SnapshotRepo.new }

  let(:dependency_tracker) { Nanoc::Int::DependencyTracker.new(dependency_store) }
  let(:dependency_store) { Nanoc::Int::DependencyStore.new(empty_items, empty_layouts, config) }
  let(:base_item) { Nanoc::Int::Item.new('base', {}, '/base.md') }

  let(:empty_items) { Nanoc::Int::ItemCollection.new(config) }
  let(:empty_layouts) { Nanoc::Int::LayoutCollection.new(config) }

  let(:config) { Nanoc::Int::Configuration.new(dir: Dir.getwd).with_defaults }

  before do
    dependency_tracker.enter(base_item)
  end

  describe '#raw_path' do
    subject { Fiber.new { view.raw_path }.resume }

    let(:view) { described_class.new(rep, view_context) }

    let(:rep) do
      Nanoc::Int::ItemRep.new(item, :default).tap do |ir|
        ir.raw_paths = {
          last: [Dir.getwd + '/output/about/index.html'],
        }
      end
    end

    let(:item) do
      Nanoc::Int::Item.new('content', {}, '/asdf.md')
    end

    context 'rep is not compiled' do
      it 'creates a dependency' do
        expect { subject }.to change { dependency_store.objects_causing_outdatedness_of(base_item) }.from([]).to([item])
      end

      it 'creates a dependency with the right props' do
        subject
        dep = dependency_store.dependencies_causing_outdatedness_of(base_item)[0]

        expect(dep.props.compiled_content?).to eq(true)

        expect(dep.props.raw_content?).to eq(false)
        expect(dep.props.attributes?).to eq(false)
        expect(dep.props.path?).to eq(false)
      end

      it { should be_a(Nanoc::Int::Errors::UnmetDependency) }
    end

    context 'rep is compiled' do
      before { rep.compiled = true }

      context 'file does not exist' do
        it 'raises' do
          expect { subject }.to raise_error(Nanoc::Int::Errors::InternalInconsistency)
        end
      end

      context 'file exists' do
        before do
          FileUtils.mkdir_p('output/about')
          File.write('output/about/index.html', 'hi!')
        end

        it 'creates a dependency' do
          expect { subject }.to change { dependency_store.objects_causing_outdatedness_of(base_item) }.from([]).to([item])
        end

        it 'creates a dependency with the right props' do
          subject
          dep = dependency_store.dependencies_causing_outdatedness_of(base_item)[0]

          expect(dep.props.compiled_content?).to eq(true)

          expect(dep.props.raw_content?).to eq(false)
          expect(dep.props.attributes?).to eq(false)
          expect(dep.props.path?).to eq(false)
        end

        it { should eq(Dir.getwd + '/output/about/index.html') }
      end
    end
  end

  describe '#compiled_content' do
    subject { view.compiled_content }

    let(:view) { described_class.new(rep, view_context) }

    let(:rep) do
      Nanoc::Int::ItemRep.new(item, :default).tap do |ir|
        ir.compiled = true
        ir.snapshot_defs = [
          Nanoc::Int::SnapshotDef.new(:last, binary: false),
        ]
      end
    end

    let(:item) do
      Nanoc::Int::Item.new('content', {}, '/asdf.md')
    end

    before do
      snapshot_repo.set(rep, :last, Nanoc::Int::TextualContent.new('Hallo'))
    end

    it 'creates a dependency' do
      expect { subject }
        .to change { dependency_store.objects_causing_outdatedness_of(base_item) }
        .from([])
        .to([item])
    end

    it 'creates a dependency with the right props' do
      subject
      dep = dependency_store.dependencies_causing_outdatedness_of(base_item)[0]

      expect(dep.props.compiled_content?).to eq(true)

      expect(dep.props.raw_content?).to eq(false)
      expect(dep.props.attributes?).to eq(false)
      expect(dep.props.path?).to eq(false)
    end

    it { should eq('Hallo') }
  end
end
