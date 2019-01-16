Rails.application.routes.draw do

  root 'welcome#index'
  post '/callback' => 'linebot#callback'

end
