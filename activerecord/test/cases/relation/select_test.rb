# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

module ActiveRecord
  class SelectTest < ActiveRecord::TestCase
    fixtures :posts, :comments

    def test_select_with_nil_argument
      expected = Post.select(:title).to_sql
      assert_equal expected, Post.select(nil).select(:title).to_sql
    end

    def test_select_with_hash_argument
      post = Post.select(:title, posts: { title: :post_title }).take
      assert_not_nil post.title
      assert_not_nil post.post_title
      assert_equal post.title, post.post_title
    end

    def test_select_with_one_level_hash_argument
      post = Post.select(:title, title: :post_title).take
      assert_not_nil post.title
      assert_not_nil post.post_title
      assert_equal post.title, post.post_title
    end

    def test_select_with_not_exists_field
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.select(foo: :post_title).take
      end
    end

    def test_select_with_hash_with_not_exists_field
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.select(posts: { boo: :post_title }).take
      end
    end

    def test_select_with_hash_array_value_with_not_exists_field
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.select(posts: [:bar, :id]).take
      end
    end

    def test_select_with_invalid_nested_field
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.select(posts: { "UPPER(title)" => :post_title }).take
      end
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.select(posts: ["UPPER(title)"]).take
      end
    end

    def test_select_with_hash_argument_without_aliases
      post = Post.select(posts: [:title, :id]).take
      assert_not_nil post.title
      assert_not_nil post.id
    end

    def test_select_with_hash_argument_with_few_tables
      post = Post.joins(:comments).select(:title, posts: { title: :post_title }, comments: { body: :comment_body }).take

      assert_equal post.title, post.post_title
      assert_not_nil post.comment_body
      assert_not_nil post.post_title
    end

    def test_reselect
      expected = Post.select(:title).to_sql
      assert_equal expected, Post.select(:title, :body).reselect(:title).to_sql
    end

    def test_reselect_with_default_scope_select
      expected = Post.select(:title).to_sql
      actual   = PostWithDefaultSelect.reselect(:title).to_sql

      assert_equal expected, actual
    end

    def test_reselect_with_hash_argument
      expected = Post.select(:title, posts: { title: :post_title }).to_sql
      actual = Post.select(:title, :body).reselect(:title, posts: { title: :post_title }).to_sql
      assert_equal expected, actual
    end

    def test_reselect_with_one_level_hash_argument
      expected = Post.select(:title, title: :post_title).to_sql
      actual = Post.select(:title, :body).reselect(:title, title: :post_title).to_sql
      assert_equal expected, actual
    end

    def test_non_select_columns_wont_be_loaded
      posts = Post.select("UPPER(title) AS title")

      assert_non_select_columns_wont_be_loaded(posts.first)
      assert_non_select_columns_wont_be_loaded(posts.preload(:comments).first)
      assert_non_select_columns_wont_be_loaded(posts.eager_load(:comments).first)
    end

    def assert_non_select_columns_wont_be_loaded(post)
      assert_equal "WELCOME TO THE WEBLOG", post.title
      assert_raise(ActiveModel::MissingAttributeError, match: /attribute 'body' for Post/) do
        post.body
      end
    end
    private :assert_non_select_columns_wont_be_loaded

    def test_merging_select_from_different_model
      posts = Post.select(:id, :title).joins(:comments)
      comments = Comment.where(body: "Thank you for the welcome")

      [
        posts.merge(comments.select(:body)).first,
        posts.merge(comments.select("comments.body")).first,
      ].each do |post|
        assert_equal 1, post.id
        assert_equal "Welcome to the weblog", post.title
        assert_equal "Thank you for the welcome", post.body
      end
    end

    def test_type_casted_extra_select_with_eager_loading
      posts = Post.select("posts.id * 1.1 AS foo").eager_load(:comments)
      assert_equal 1.1, posts.first.foo
    end

    def test_aliased_select_using_as_with_joins_and_includes
      posts = Post.select("posts.id AS field_alias").joins(:comments).includes(:comments)
      assert_equal %w(id field_alias), posts.first.attributes.keys
    end

    def test_aliased_select_not_using_as_with_joins_and_includes
      posts = Post.select("posts.id field_alias").joins(:comments).includes(:comments)
      assert_equal %w(id field_alias), posts.first.attributes.keys
    end

    def test_star_select_with_joins_and_includes
      posts = Post.select("posts.*").joins(:comments).includes(:comments)
      assert_equal %w(
        id author_id title body type legacy_comments_count taggings_with_delete_all_count taggings_with_destroy_count
        tags_count indestructible_tags_count tags_with_destroy_count tags_with_nullify_count
      ), posts.first.attributes.keys
    end

    def test_enumerate_columns_in_select_statements
      original_value = Post.enumerate_columns_in_select_statements
      Post.enumerate_columns_in_select_statements = true
      sql = Post.all.to_sql
      Post.column_names.each do |column_name|
        assert_includes sql, column_name
      end
    ensure
      Post.enumerate_columns_in_select_statements = original_value
    end

    def test_select_without_any_arguments
      error = assert_raises(ArgumentError) { Post.select }
      assert_equal "Call `select' with at least one field.", error.message
    end

    def test_select_with_block_without_any_arguments
      error = assert_raises(ArgumentError) do
        Post.select("invalid_argument") { }
      end

      assert_equal "`select' with block doesn't take arguments.", error.message
    end
  end
end
