class Template
  module BuiltinCommands
    class Include < Papyrus::Commands::Include
      def get_template_source
        cdx_template = self.template.options[:extra][:cdx_template]
        tpl = cdx_template.journal.templates.custom.find_by_name(@template_name)
        tpl ? tpl.raw_content : ""
      end
    end
  end
end
