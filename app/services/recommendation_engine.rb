class RecommendationEngine
  def initialize(favorite_movies)
    @favorite_movies = favorite_movies
  end
  # LOGIC: Recommendations only work based by genre. That's too limited. We can crossmatch other factors that
  # potentially indicate what constitutes a movie a customer might like, such as duration, director, movie release-dates which could 
  # indicate a preference for image quality, trends based by the period the movie was filmed in, etc.
  # Another potiential improvement is cross-matching data from users who also had a certain movie as their favorite and suggest
  # other favorites from the people who also had said movie as their favorite since people are often shown to have similar tastes
  
  # PERFORMANCE: Prediction algorithms are known to take a lot of processing time, changing the aforementioned logic could help in some ways
  # If recommendations by other users' taste are implemented, a much shorter list will be a source of calculations. Limiting for a
  # specific ammount of users to search from and possibly crossmatching with favorite genres, there could be a much quicker
  # recommendation feature, allowing the customer to recalculate if they deem it necessary. Of course, ideally recommendations
  # should work and then there would not be a need to recalculate, but it opens up features like these with time limitations.

  # ERROR HANDLING: Needs failsafes for when requests fails or data is incomplete.

  def recommendations
    movie_titles = get_movie_names(@favorite_movies)
    genres = Movie.where(title: movie_titles).pluck(:genre)
    common_genres = genres.group_by{ |e| e }.sort_by{ |k, v| -v.length }.map(&:first).take(3)
    Movie.where(genre: common_genres).order(rating: :desc).limit(10)
  end

  private

  def get_movie_names(movies)
    names = []
    @favorite_movies.each do |movie|
      names << movie.title
    end

    return names
  end
end