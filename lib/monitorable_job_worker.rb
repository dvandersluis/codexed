class MonitorableJobWorker < JobWorker
  
  attr_reader :progress, :goal, :activity, :subgoal, :subprogress, :subactivity, :subactivity_params, :last_updated_progress_at, :step_offset
  
  def initialize(*args)
    super
    @goal = nil
    @progress = nil
    @activity = nil
    @subgoal = nil
    @subprogress = nil
    @subactivity = nil
    @subactivity_params = nil
    @started_at = Time.now
    @last_updated_progress_at = nil
    @last_updated_subprogress_at = nil
    @time_factor = nil
  end
  
  def new_goal!(goal)
    @goal = goal
    @progress = 0
  end

  def new_activity!(activity)
    puts " - #{I18n.t(activity, :scope => "workers.#{@job.worker_class.underscore.split('_').first}")}"
    @activity = activity
    clear_subgoal!
    @step_offset = @step_offsets[@progress] if @step_offsets
  end

  def advance_progress!(amount=nil)
    @progress += (amount || 1)
    now = Time.now
    diff = now.to_f - (@last_updated_progress_at || @started_at).to_f
    @last_updated_progress_at = now
    puts "   Progress is: #{progress} / #{goal} (#{diff} seconds)"
  end

  def new_subgoal!(subgoal)
    @subgoal = subgoal
    @subprogress = 0
  end

  def clear_subgoal!
    @subgoal = nil
    @subprogress = nil
  end

  def new_subactivity!(activity, activity_params = {})
    activity_params[:scope] = "workers.#{@job.worker_class.underscore.split('_').first}"
    puts "   - #{I18n.t(activity, activity_params)}"
    @subactivity = activity
    @subactivity_params = activity_params
  end

  def advance_subprogress!(amount=nil)
    @subprogress += (amount || 1)
    now = Time.now
    diff = now.to_f - (@last_updated_subprogress_at || @started_at).to_f
    @last_updated_subprogress_at = now
    puts "     Subprogress is: #{subprogress} / #{subgoal} (#{diff} seconds)"
  end
end
