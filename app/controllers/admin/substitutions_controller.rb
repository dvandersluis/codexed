class Admin::SubstitutionsController < Admin::BaseController
  
  before_filter :set_user_and_journal
  
  def index
    @subs = @journal.subs.to_a
    @messages = []

    if request.post?
      sub_names = [] 
      
      zipped_subs = params[:subs].zip(@subs)

      @subs = zipped_subs.inject([]) do |memo, (new_sub, old_sub)|
        if old_sub
          if new_sub[:name].blank?
            # existent sub was deleted
            old_sub.destroy
          else
            if old_sub.value != new_sub[:value]
              # sub was updated
              old_sub.value = new_sub[:value]
            end
            if old_sub.name != new_sub[:name]
              # sub was renamed
              old_sub.name = new_sub[:name]
            end
            memo << old_sub
          end
        else
          if new_sub[:name].blank?
            # uhm, this shouldn't have happened
          else
            # new sub was added
            new_sub = @journal.subs.create(new_sub)
            memo << new_sub
          end
        end
        memo
      end

      # Only save if all subs are valid, otherwise spit out some error messages!
      if @subs.inject(true) { |bool, sub| bool && sub.valid? }
        @subs.each { |sub| sub.save }
        @success = t(:substitutions_saved)
        @subs.sort!
      else
        @subs.each do |sub|
          if !sub.valid?
            sub.errors.each { |attr, msg| @messages.push("[#{sub.name}] #{msg}") }
          end
        end
      end
    end

    # Ensure that 5 blank substitution boxes are available
    5.times { @subs << Sub.new }
  end
end
