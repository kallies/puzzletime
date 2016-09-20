Rails.application.routes.draw do

  root to: 'worktimes#index'

  resources :absences, except: [:show]

  resources :clients, except: [:show] do
    collection do
      get :categories
      get :contacts_with_crm, to: 'contacts#with_crm'
    end

    resources :billing_addresses
    resources :contacts
  end

  resources :departments, except: [:show]

  resources :employees do
    collection do
      get :settings
      patch :settings, to: 'employees#update_settings'
      get :passwd
      post :passwd, to: 'employees#update_passwd'
    end

    resources :employments, except: [:show]
    resources :overtime_vacations, except: [:show]
    resource :worktimes_commit, only: [:edit, :update]
  end

  resources :employee_lists

  resources :holidays, except: [:show]

  resources :orders do
    collection do
      post :crm_load
    end

    member do
      get :bills
      get :employees
    end

    resources :accounting_posts, except: [:show]

    resource :contract, only: [:show, :edit, :update]

    resource :multi_worktimes, only: [:update] do
      post :edit
      get :edit, to: redirect('/orders/%{order_id}/order_services')
    end

    resources :order_comments, only: [:index, :create]
    resource :order_targets, only: [:show, :update]

    resource :order_services, only: [:show, :edit, :update] do
      get :export_worktimes_csv
      get :compose_report
      get :report
    end

    resources :invoices do
      collection do
        get :preview_total
        get :billing_addresses
        get :filter_fields
      end
      member do
        put :sync
      end
    end

    resource :month_end_completion, only: [:edit, :update]
  end

  resources :order_statuses, except: [:show]

  resources :order_kinds, except: [:show]

  resources :portfolio_items, except: [:show]

  resources :sectors, except: [:show]

  resources :services, except: [:show]

  resources :target_scopes, except: [:show]

  resources :user_notifications, except: [:show]

  resources :work_items, only: [:new, :create] do
    collection do
      get :search
    end
  end

  resources :working_conditions, except: [:show]

  resources :worktimes, only: [:index]

  resources :ordertimes do
    collection do
      get :existing
      get :split
      match :create_part, via: [:post, :patch]
      match :delete_part, via: [:post, :delete]
    end
  end

  resources :absencetimes do
    collection do
      get :existing
    end
  end

  scope '/evaluator', controller: 'evaluator' do
    get ':action'

    post :change_period
  end

  namespace :plannings do
    resources :orders, only: [:index, :show, :update, :destroy] do
      get 'new', on: :member, as: 'new'
    end
    resources :employees, only: [:index, :show, :update, :destroy] do
      get 'new', on: :member, as: 'new'
    end
    resource :multi_orders, only: [:show, :new, :update, :destroy]
    resource :multi_employees, only: [:show, :new, :update, :destroy]
  end

  resource :graph, only: [], controller: :graph do
    get :weekly
    get :all_absences
  end

  scope '/reports' do
    get '/orders', to: 'order_reports#index', as: :reports_orders
    get '/workload', to: 'workload_report#index', as: :reports_workload
  end

  scope '/login', controller: 'login' do
    match :login, via: [:get, :post]
    post :logout
  end

  get 'status', to: 'status#index'

  get '/404', to: 'errors#404'
  get '/500', to: 'errors#500'
  get '/503', to: 'errors#503'

  get 'design_guide', to: 'design_guide#index'

  # Install the default route as the lowest priority.
  #match '/:controller(/:action(/:id))', via: [:get, :post, :patch]


  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
