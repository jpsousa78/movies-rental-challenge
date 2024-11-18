class MoviesController < ApplicationController
  
  # ERROR HANDLING: The entire controller needs failsafes for when requests fails or data is incomplete.

  # Could `Movie.all` be potentially dangerous due to the size of the catalog?
  # If rendering in the frontend becomes an issue, one improvement would be to create a priority queue
  # and index the most relevant movies and genres first with pagination, updating the list with the remaining movies upon request
  def index
    begin
      @movies = Movie.all
      render json: @movies, status: :ok
    rescue => e
      render json: {error: "An unexpected error occurred retrieving movies: #{e.message}"}, status: :internal_server_error
    end
  end

  # More comments at the RecommendationEngine
  def recommendations
    begin
      user = User.find(params[:user_id])
      favorite_movies = user.favorites
      
      if favorite_movies.empty?
        render json: {message: "No favorite movies found for this user"}, status: :ok # Not a failure, just a corner case ocurrence
      else
        @recommendations = RecommendationEngine.new(favorite_movies).recommendations
        render json: @recommendations, status: :ok
      end

    # Raises exceptions for either movies or users not found
    # If we want to separate them to two unique exceptions we could use "if e.message.include?('User') or ('Movie')"
    # and respond accordingly. We could also use two separate exception handlers, although not ideal.
    # In any case, the most important part is in the error message.
    rescue ActiveRecord::RecordNotFound => e 
      render json: {error: "Record not found: #{e.message}"}, status: :not_found

    rescue => e # Cover other unexpected exceptions
      render json: {error: "An unexpected error occurred: #{e.message}"}, status: :internal_server_error
    end
  end

  # Feature suggestion: implement a token-based authentication method so only customers and admins/automations can see this list (privacy)
  def user_rented_movies
    begin
      user = User.find(params[:user_id])
      @rented = user.rented

      if @rented.empty?
        render json: {message: "No rented movies found for this user"}, status: :ok # Not a failure, just a corner case ocurrence
      else
        render json: @rented, status: :ok
      end

    rescue ActiveRecord::RecordNotFound => e
      render json: {error: "User not found: #{e.message}"}, status: :not_found

    rescue => e # Cover other unexpected exceptions
      render json: {error: "An unexpected error occurred: #{e.message}"}, status: :internal_server_error
    end
  end

  # Does it work asynchronously? If so, migh have trouble when two customers order the same movie
  # If User.find or Movie.find fail, the following operations create data inconsistency
  def rent
    begin
      user = User.find(params[:user_id])
      movie = Movie.find(params[:id])

      if movie.available_copies > 0
        # According to standard practices on Ruby on rails, ApplicationRecord.transaction unify the success
        # or failure of multiple dependent operations. Therefore, they all must succeed or every change is
        # rolled back
        ApplicationRecord.transaction do
          movie.available_copies -= 1 # Include a migration in `Movie` to add a clause to forbid negative numbers
          movie.save! # Including '!' to raise invalid record saving in case of wrong data validation
          user.rented << movie
        end
        render json: {message: "Movie rental successfull", movie: movie}, status: :ok # Not a failure, just a corner case ocurrence
      else
        render json: {error: "No available copies left for this movie"}, status: :unprocessable_entity
      end
    
    rescue ActiveRecord::RecordNotFound => e # Find error
      render json: {error: "Record not found: #{e.message}"}, status: :not_found
    rescue ActiveRecord::RecordInvalid => e # ApplicationRecord.transaction error
      render json: {error: "Invalid record: #{e.message}"}, status: :unprocessable_entity
    rescue => e # Other errors
      render json: {error: "An unexpected error occurred: #{e.message}"}, status: :internal_server_error
    end
  end

  def return_rental
    begin
      user = User.find(params[:user_id])
      movie = Movie.find(params[:id])

      if user.rented.include?(movie)
        ApplicationRecord.transaction do
          movie.available_copies += 1
          movie.save!
          # As of now, "rented" shows movies currently in customer possession, however, it would be
          # beneficial to include a history of rentals as well. That can be justified for security reasons,
          # product damage assessment, further options on recommendation, etc...
          user.rented.delete(movie)
        end
        render json: { message: "Movie returned successfully", movie: movie }, status: :ok
      else
        render json: { error: "Movie not found in user's current rentals" }, status: :not_found
      end

    rescue ActiveRecord::RecordNotFound => e # Find error
      render json: { error: "User or movie not found: #{e.message}" }, status: :not_found
    rescue ActiveRecord::RecordInvalid => e # ApplicationRecord.transaction error
      render json: { error: "Invalid record: #{e.message}" }, status: :unprocessable_entity
    rescue => e # Other errors
      render json: { error: "An unexpected error occurred: #{e.message}" }, status: :internal_server_error
    end
  end
end