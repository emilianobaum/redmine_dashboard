# frozen_string_literal: true

class RdbDashboardController < ApplicationController
  unloadable
  menu_item :dashboard
  before_action :find_project, :authorize
  before_action :setup_board, except: :index
  before_action :find_issue, only: %i[move update]
  before_action :authorize_edit, only: %i[move update]
  after_action :save_board_options

  def index
    return redirect_to rdb_taskboard_url if params[:controller] == 'rdb_dashboard'

    setup_board params
  end

  def filter
    @board.update params
    render action: 'index'
  end

  def update
    render_404
  end

  def move
    render_404
  end

  private

  def board_type
    nil
  end

  def board
    board_type.new(@project, options_for(board_type.name), params)
  end

  def setup_board(params = nil)
    return render_404 unless (@board = board)

    @board.setup params if params
    @board.build
    @board
  end

  def save_board_options
    save_options_for(@board.options, board_type.name) if @board
  end

  def authorize_edit
    raise Unauthorized unless User.current.allowed_to?(:edit_issues, @project)
  end

  def find_project
    @project = Project.find params[:id]
  end

  def find_issue
    flash_error :rdb_flash_missing_lock_version and return false unless params[:lock_version]

    @issue = Issue.find params[:issue]

    if @issue.lock_version != params[:lock_version].to_i
      flash_error :rdb_flash_stale_object, update: true, issue: @issue.subject
      return false
    end

    @issue.lock_version = params[:lock_version].to_i
    @issue
  end

  def flash_error(sym, options = {})
    flash.now[:rdb_error] = I18n.t(sym, options).html_safe
    Rails.logger.info "Render Rdb flash error: #{sym}"
    options[:update] ? render('index.js') : render('error.js')
  end

  def options_for(board)
    session["dashboard_#{@project.id}_#{User.current.id}_#{board}"] ||= {}
  end

  def save_options_for(options, board)
    session["dashboard_#{@project.id}_#{User.current.id}_#{board}"] = options
  end

  def session_id
    "dashboard_#{@project.id}_#{User.current.id}"
  end
end
