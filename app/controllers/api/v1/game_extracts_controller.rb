require 'base64'
require 'image_to_score'

include ImageToScore

class Api::V1::GameExtractsController < ApplicationController
    skip_before_filter  :verify_authenticity_token

    def create
        b64encImg = params[:image].partition('base64,')[2];
        b64decImg = Base64.decode64(b64encImg);
        buf = OpenCV::cv::Mat.new(1, b64decImg.length, OpenCV::cv::CV_8U, b64decImg);
        decImg = OpenCV::cv::imdecode(buf, 1);
        score = processImg(decImg)
        # img = OpenCV::cv::imdecode(b64decImg, 1);
        respond_to do |format|
            # format.json { render json: {width: decImg.cols, height: decImg.rows}}
            format.json { render json: {score: score}}
        end
    end
end
