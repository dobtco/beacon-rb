class OpportunitiesController < ApplicationController
  include OpportunitiesHelper

  before_action :set_opportunity

  def index
    skip_authorization
    @opportunities = Opportunity.posted.filter(opportunity_filter_params)
  end

  def feed
    skip_authorization
    @opportunities = Opportunity.posted.filter(
      opportunity_filter_params.merge(
        sort: 'updated_at',
        direction: 'desc'
      )
    )
  end

  def pending
    authorize :opportunity, :approve?

    @pending_approval_opportunities = Opportunity.
                                        not_approved

    @pending_publish_opportunities = Opportunity.
                                      not_published.
                                      approved
  end

  def new
    authorize_staff
    @opportunity = Opportunity.new
  end

  def create
    authorize_staff

    @opportunity = Opportunity.new(
      opportunity_params.merge(created_by_user: current_user)
    )

    if @opportunity.save
      redirect_to edit_opportunity_path(@opportunity, step: 'description')
    else
      render :new
    end
  end

  def edit
    unless params[:step].in?(edit_opportunity_steps)
      params[:step] = edit_opportunity_steps.first
    end

    authorize @opportunity, :edit?
  end

  def request_approval
    authorize @opportunity, :edit?
    !@opportunity.submitted_for_approval? || deny_access
    @opportunity.submit_for_approval!
    request_approval_from_approvers_and_admins
    redirect_to :back
  end

  def update
    authorize @opportunity, :edit?

    if @opportunity.update(opportunity_params)
      if params[:rename]
        redirect_to :back
      elsif next_step
        redirect_to edit_opportunity_path(@opportunity, step: next_step)
      else
        redirect_to opportunity_path(@opportunity)
      end
    else
      render :edit
    end
  end

  def destroy
    authorize @opportunity, :destroy?
    @opportunity.trash!

    redirect_to(
      if policy(:opportunity).approve?
        pending_opportunities_path
      else
        root_path
      end
    )
  end

  def show
    authorize @opportunity, :show?

    if @opportunity.enable_questions?
      @questions = @opportunity.questions.unanswered_first
    end
  end

  def approve
    authorize @opportunity, :approve?

    if @opportunity.approved?
      @opportunity.unapprove!
    else
      @opportunity.approve!
    end

    redirect_to pending_opportunities_path,
                success: t('approved_success')
  end

  def subscribe
    authorize @opportunity, :subscribe?

    if current_user.opportunities.include?(@opportunity)
      current_user.opportunities.destroy(@opportunity)
    else
      current_user.opportunities << @opportunity
      flash[:success] = t('subscribed_success')
    end

    redirect_to :back
  end

  def submit
    authorize @opportunity, :submit?
    deny_access unless @opportunity.submission_page
  end

  private

  def set_opportunity
    if params[:id]
      @opportunity = Opportunity.find(params[:id])

      # Verify slug is correct
      if @opportunity && (params[:id] != @opportunity.to_param)
        redirect_to url_for(id: @opportunity.to_param),
                    status: :moved_permanently
      end
    end
  end

  def opportunity_params
    params.require(:opportunity).permit(
      :title,
      :description,
      :department_id,
      :contact_name,
      :contact_email,
      :contact_phone,
      :submission_adapter_name,
      :publish_at,
      :submissions_open_at,
      :submissions_close_at,
      :enable_questions,
      :questions_open_at,
      :questions_close_at,
      category_ids: []
    ).tap do |h|
      # Allow all
      if (x = params[:opportunity][:submission_adapter_data]).present?
        h[:submission_adapter_data] = x
      end
    end
  end

  def next_step
    edit_opportunity_steps[edit_opportunity_steps.index(params[:step]) + 1]
  end

  def opportunity_filter_params
    params.merge(params[:opportunity_filters] || {}).tap do |h|
      # Selectize sends us an array that includes an empty element
      h[:category_ids].reject!(&:blank?) if h[:category_ids]
    end
  end

  def request_approval_from_approvers_and_admins
    User.approvers_and_admins.each do |user|
      Mailer.approval_request(user, @opportunity).deliver_later
    end
  end
end
