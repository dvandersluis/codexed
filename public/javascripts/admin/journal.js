updateProgressTimers = {};
openingAnimationPlayed = false;
lastJob = null;
DURATION = 0.2;

function changeProgressBarWidthBy(bar, pct) {
  var bar = $(bar);
  var newPct = parseInt(bar.style.width) + pct;
  updateProgressBar(bar, newPct);
}
function updateProgressBar(bar, newPct) {
  var bar = $(bar);
  bar.morph({ style: {width: newPct+"%"}, duration: DURATION });
}

function morphBoxHeight(box, height, afterFinish) {
  var box = $(box);
  if (height == "auto") height = box.scrollHeight + 5;
  box.morph({
    style: { height: height+"px" },
    duration: DURATION,
    beforeSetup: function() {
      box.setStyle({ overflow: "hidden" });
    },
    afterFinish: function() {
      afterFinish(box);
    }
  });
}

function startUpdatingProgress(type, tokenName, tokenValue) {
  updateProgressTimers[type] = new PeriodicalExecuter(function() {
    var parameters = {}; parameters[tokenName] = tokenValue;
    new Ajax.Request('/admin/journal/'+type+'/update_progress', {
      asynchronous: true,
      evalScripts: true,
      parameters: parameters
    })
  }, 2)
}
function stopUpdatingProgress(type) {
  updateProgressTimers[type].stop();
}

function updateProgress(type, job, partial, timeRemaining, tempActivity) {
  if (job.state != "pending" && job.state != "running") {
    stopUpdatingProgress(type);
    updateProgressBar(type+"_progress_bar_fill", 100);
    updateProgressBar(type+"_subprogress_bar_fill", 100);
    morphBoxHeight(type+"_progress_box", 5, function() { $(type+"_stuff").update(partial) });
  }
  else if (job.state == "pending") {
    // do nothing
  }
  else if (lastJob && lastJob.state == "pending" && job.state == "running") {
    fromPendingToRunning(type, job, timeRemaining, tempActivity);
  }
  else {
    if (lastJob && job.progress > lastJob.progress) {
      // completed sub-goal
      updateProgressBar(type+"_subprogress_bar_fill", 100);
      (function() { $(type+"_subprogress_bar_fill").setStyle({width: 0}) }).delay(DURATION * 2);
      updateProgressBox.delay(DURATION * 3, type, job, timeRemaining);
    } else {
      updateProgressBox(type, job, timeRemaining);
    }
  }
  lastJob = job;
}

function fromPendingToRunning(type, job, timeRemaining, tempActivity) {
  (function() {
    $(type+'_activity').update(tempActivity);
  }).delay(DURATION * 1.5);
  
  (function() {
    $(type+"_progress_bar_bg").removeClassName('animated');
    $(type+"_progress_bar_fill").addClassName('animated');
    morphBoxHeight(type+"_progress_box", "auto", function(box) {
      box.setStyle({ overflow: "", height: "" });
      updateProgressBox(type, job, timeRemaining);
    });
  }).delay(DURATION * 3);
}

function updateProgressBox(type, job, timeRemaining) {
  if (job.activity.length) $(type+"_activity").update(job.activity); // Only update if there is some text to show
  updateProgressBar(type+"_progress_bar_fill", job.progress_percentage);
  $(type+"_subactivity").update(job.subactivity);
  updateProgressBar(type+"_subprogress_bar_fill", job.subprogress_percentage);
  if (timeRemaining) $(type+"_job_info").update(timeRemaining);
}
