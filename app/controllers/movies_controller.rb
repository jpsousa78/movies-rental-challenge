class MoviesController < ApplicationController
  
  # ERROR HANDLING: The entire controller needs failsafes for when requests fails or data is incomplete.

  # Could `Movie.all` be potentially dangerous due to the size of the catalog?
  # If rendering in the frontend becomes an issue, one improvement would be to create a priority queue
  # and index the most relevant movies and genres first with pagination, updating the list with the remaining movies upon request
  def index
    @movies = Movie.all
    render json: @movies
  end

  # More comments at the RecommendationEngine
  def recommendations
    favorite_movies = User.find(params[:user_id]).favorites
    # No error treatment. What if user is not logged in, request fails to fetch or the user has no registered favorite movies?
    @recommendations = RecommendationEngine.new(favorite_movies).recommendations
    render json: @recommendations
  end

  # Feature suggestino: implement a token-based authentication method so only customers and admins can see this list (privacy)
  def user_rented_movies
    @rented = User.find(params[:user_id]).rented
    render json: @rented
  end

  # Does it work asynchronously? If so, migh have trouble when two customers order the same movie
  # If User.find or Movie.find fail, the following operations create data inconsistency
  def rent
    user = User.find(params[:user_id])
    movie = Movie.find(params[:id])
    movie.available_copies -= 1 # Does not check if there are available copies
    movie.save
    user.rented << movie
    render json: movie
  end

  # No return_movie method??
end