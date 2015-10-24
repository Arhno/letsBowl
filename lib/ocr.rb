module Ocr
    require 'matrix'
    require 'ropencv'


    class Ocr
        def initialize(filename)
            f = open(filename)

            labels = []
            means = {}
            covariances = {}

            (0..11).each do |i|
                label = f.readline.strip

                labels << label

                means[label] = Matrix.column_vector(f.readline.strip.split(',').collect! {|s| s.to_f})

                cov = []
                n = means[label].row_count
                (1..n).each do |j|
                    cov << f.readline.strip.split(',').collect! {|s| s.to_f}
                end
                covariances[label] = Matrix.rows(cov)
            end

            @classifier = GaussianClassifier.new(labels, means, covariances)
        end

        def getInternal(img)
            contours = OpenCV::Std::Vector::Cv_Mat.new
            hierarchy = OpenCV::cv::Mat.new
            OpenCV::cv::findContours(img, contours, hierarchy, OpenCV::cv::RETR_CCOMP, OpenCV::cv::CHAIN_APPROX_SIMPLE)
            return contours.size - 1
        end

        def predict(img)
            moments = OpenCV::cv::moments(img, true)
            moment_names = ['m00', 'mu20', 'mu11', 'mu02', 'mu30', 'mu21', 'mu12', 'mu03']

            x = []
            moment_names.each do |m|
                x << moments.send(m)
            end

            x << getInternal(img)

            x = Matrix.column_vector(x)

            return @classifier.predict(x)
        end
    end


    class GaussianClassifier
        def initialize(labels, means, covariances, threshold = 1e-35)
            @labels = labels
            @means = means
            @covariances = covariances
            @threshold = threshold
        end

        def predict(x)
            res = -1
            label = "None"
            @labels.each do |l|
                cur_res = gaussian(x, @means[l], @covariances[l])
                if cur_res > res and cur_res > @threshold
                    res = cur_res
                    label = l
                end
            end
            return label
        end

        private

        def gaussian(x, mean, cov)
            n = mean.row_count
            det = cov.det
            div = Math.sqrt(det * ((2*Math::PI)**n))

            diff = x - mean
            num = diff.t * cov.inv * diff

            return Math.exp(-0.5 * num[0,0]) / div
        end
    end

end
