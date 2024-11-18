class RecommendationEngine
  def initialize(favorite_movies)
    @favorite_movies = favorite_movies
  end
  # LOGIC: Recommendations only work based by genre. That's too limited. We can crossmatch other factors that
  # potentially indicate what constitutes a movie a customer might like, such as duration, director, movie release-dates which could 
  # indicate a preference for image quality, trends based by the period the movie was filmed in, etc.
  # However, this means major changes in schemas to be aligned with the product team


  # Provided that the schema changes are made, here are some optimizations
  def recommendations
    begin
      if @favorite_movies.empty?
        render json: {error: "No favorite movies provided"}, status: :not_found
      
      genres = @favorite_movies.map(&:genre) # If genre cannot be required, a '.compact' would exclude empties from the list

      common_genres = genres.each_with_object(Hash.new(0)) {|genre, counts| counts[genre] += 1} # HashMap {genre, count}
                      .sort_by {|_, count| -count}.first(3).map(&:first)

      Movie.where(genre: common_genres).order(rating: :desc).limit(10)

    rescue ActiveRecord::RecordNotFound => e
      render json: {error: "Record not found: #{e.message}"}, status: :not_found
      
    rescue => e
      render json: {error: "An unexpected error occurred: #{e.message}"}, status: :internal_server_error
    end
  end

  # Upon changes in schema, the get_movie function is no longer needed
  # The following is an implementation based on a previous suggestion of recommending based on shared interests amongst users

  def shared_recommendations
    begin
      similar_users = find_similar_users(@favorite_movies)

      raise "No similar users" if similar_users.empty?

      recommended_movies = get_movies_from_similar_users(similar_users, @favorite_movies)

      raise "No shared recommended movies" if recommended_movies.empty?

      recommended_movies.order(rating: :desc).limit(10)

    rescue => e
      render json: {error: "Error in generating recommendations: #{e.message}"}, status: :internal_server_error
    end
  end

  def find_similar_users(@favorite_movies)
    
    other_users = User.where.not(id: @user.id) # For performance's sake, we can put a .limit(n) at the end of this query
                                               # But for that we would need to determine what would be an effective sample size
    
    return [] if other_users.empty?
    
    user_similarity = other_users.map do |user|
      common_movies = (user.favorite_movies & @favorite_movies).size
      {user: user, common_movie_count: common_movies}
    end
    
    return [] if user_similarity.empty?

    user_similarity.sort_by {|data| -data[:common_movie_count]}.select {|data| data[:common_movie_count] > 0}
    
    return [] if user_similarity.empty?

  end

  def get_movies_from_similar_users(similar_users, @favorite_movies)
    recommended_movies = []

    similar_users.each do |user_data|
      new_movies = user_data.favorite_movies - @favorite_movies # Ensure the recommendations come with an unseen movie
      recommended_movies.concat(new_movies)
    end

    Movie.where(id: recommended_movies.uniq)
  end
end