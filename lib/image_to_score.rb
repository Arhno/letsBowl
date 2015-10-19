module ImageToScore
    require 'ropencv'
    load 'ocr.rb'

    def binarize(img)
        grey = OpenCV::cv::Mat.new
        OpenCV::cv::cvtColor(img, grey, OpenCV::cv::COLOR_BGR2GRAY)
        adaptive = OpenCV::cv::Mat.new
        OpenCV::cv::adaptiveThreshold(grey, adaptive, 255,
                                      OpenCV::cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                                      OpenCV::cv::THRESH_BINARY, 81, -25)

        cleaned = OpenCV::cv::Mat.new
        kernel = OpenCV::cv::Mat::ones(1, 1, OpenCV::cv::CV_8UC1)
        OpenCV::cv::morphologyEx(adaptive, cleaned, OpenCV::cv::MORPH_OPEN, kernel)
        return cleaned
    end

    def getCandidates(img)
        contours = OpenCV::Std::Vector::Cv_Mat.new
        hierarchy = OpenCV::cv::Mat.new
        #hierarchy = OpenCV::Std::Vector::Cv_Vec4i.new
        OpenCV::cv::findContours(img, contours, hierarchy, OpenCV::cv::RETR_CCOMP, OpenCV::cv::CHAIN_APPROX_SIMPLE)

        candidates = {}

        n = contours.size

        for i in 0..(n-1)
            #puts hierarchy[i]
            if hierarchy[0,i,3] == -1
                bb = OpenCV::cv::boundingRect(contours[i])
                if bb.width >= 20 && bb.width <= 40 && bb.height >=30 && bb.height <= 100
                    ratio = (1.0*bb.width)/bb.height
                    if (ratio >= 0.2 && ratio <= 0.5) || (ratio >= 0.55 && ratio <= 0.99)
                        candidates[i] = {external: contours[i], internal: []}
                    end
                end
            end
        end

        for i in 0..(n-1)
            if candidates.has_key?(hierarchy[0,i,3])
                bb = OpenCV::cv::boundingRect(contours[i])
                if bb.width >= 5 and bb.height >= 5
                    candidates[hierarchy[0,i,3]][:internal] << contours[i]
                end
            end
        end

        return candidates
    end

    def getRatio(c)
        bb = OpenCV::cv::boundingRect(c)
        w = bb.width
        h = bb.height
        ratio = (1.0*w)/h
        return ratio
    end

    def getAverageRatio(candidates)
        mean1 = 0
        nb1 = 0
        mean2 = 0
        nb2 = 0
        candidates.each_value do |c|
            ratio = getRatio(c[:external])
            if ratio <= 0.5
                nb1 += 1
                mean1 += ratio
            else
                nb2 += 1
                mean2 += ratio
            end
        end

        #puts mean1, mean2, nb1, nb2

        if nb1 > nb2
            return mean1 / nb1
        elsif nb2 > 0
            return mean2 / nb2
        end

        puts "No candidates"
        return -1
    end

    def prune(candidates, targetRatio)
        candidates.delete_if do |k, c|
            ratio = getRatio(c[:external])
            (ratio - targetRatio).abs > 0.3 * targetRatio
        end

        return candidates
    end

    def getVignette(candidate, ratio)
        c = candidate[:external]
        bb = OpenCV::cv::boundingRect(c)
        x = bb.x
        y = bb.y
        h = bb.height
        w = bb.width
        number = OpenCV::cv::Mat.new
        if ratio < 0.55
            number = OpenCV::cv::Mat::zeros(h, h, OpenCV::cv::CV_8UC1)
            contours = OpenCV::Std::Vector::Cv_Mat.new
            contours << c
            OpenCV::cv::drawContours(number, contours, -1, OpenCV::cv::Scalar.new(255), -1, 8, OpenCV::cv::Mat.new, OpenCV::cv::INT_MAX, OpenCV::cv::Point.new(h/2 - w/2 - x, -y))
            for c in candidate[:internal]
                contours = OpenCV::Std::Vector::Cv_Mat.new
                contours << c
                OpenCV::cv::drawContours(number, contours, -1, OpenCV::cv::Scalar.new(0), -1, 8, OpenCV::cv::Mat.new, OpenCV::cv::INT_MAX, OpenCV::cv::Point.new(h/2 - w/2 - x, -y))
            end
        else
            number = OpenCV::cv::Mat::zeros(h, 2*h, OpenCV::cv::CV_8UC1)
            contours = OpenCV::Std::Vector::Cv_Mat.new
            contours << c
            OpenCV::cv::drawContours(number, contours, -1, OpenCV::cv::Scalar.new(255), -1, 8, OpenCV::cv::Mat.new, OpenCV::cv::INT_MAX, OpenCV::cv::Point.new(h - w/2 - x, -y))
            for c in candidate[:internal]
                contours = OpenCV::Std::Vector::Cv_Mat.new
                contours << c
                OpenCV::cv::drawContours(number, contours, -1, OpenCV::cv::Scalar.new(0), -1, 8, OpenCV::cv::Mat.new, OpenCV::cv::INT_MAX, OpenCV::cv::Point.new(h - w/2 - x, -y))
            end
        end

        OpenCV::cv::resize(number, number, OpenCV::cv::Size.new(40, 40))

        return number
    end

    class Element
        attr_reader :number, :xmin, :xmax, :ymin, :ymax

        def initialize(number, xmin, xmax, ymin, ymax)
            @number = number
            @xmin = xmin
            @xmax = xmax
            @ymin = ymin
            @ymax = ymax
        end

        def isCloseFrom(other)
            return (other.xmin > @xmax && other.xmin - @xmax < 25) || (xmin > other.xmax && @xmin - other.xmax < 25)
        end

        def mergeWith(other)
            xmin = [@xmin, other.xmin].min
            xmax = [@xmax, other.xmax].max
            ymin = [@ymin, other.ymin].min
            ymax = [@ymax, other.ymax].max
            number = ""
            if @xmin < other.xmin
                number = @number + other.number
            else
                number = other.number + @number
            end

            return Element.new(number, xmin, xmax, ymin, ymax)
        end
    end

    class Line
        attr_reader :top, :bottom
        def initialize(top, bottom)
            @top = top
            @bottom = bottom
            @elements = []
            @already_sorted = true
        end

        def isIn(element)
            y = (element.ymin + element.ymax) / 2
            return (y > @top) && (y < @bottom)
        end

        def add(element)
            @elements << element
            already_sorted = false
        end

        def elements()
            @elements.sort_by!{|e| e.xmin}
            merged_elements = []
            n = @elements.length
            cur = @elements[0]
            isScoreLine = true
            for i in 1..(n-1)
                if @elements[i].number == '/' or @elements[i].number == 'X'
                    isScoreLine = false
                    break
                end
                if cur.isCloseFrom(@elements[i])
                    cur = cur.mergeWith(@elements[i])
                else
                    merged_elements << cur
                    cur = @elements[i]
                end
            end
            merged_elements << cur

            if isScoreLine
                @elements = merged_elements
            end

            @already_sorted = true

            return @elements
        end
    end

    def getLines(candidates)
        lines = []
        candidates.each do |c|
            found = false
            lines.each do |l|
                if l.isIn(c)
                    found = true
                    l.add(c)
                    break
                end
            end
            if not found
                l = Line.new(c.ymin, c.ymax)
                l.add(c)
                lines << l
            end
        end

        lines.sort_by! {|l| l.top}

        return lines
    end

    def getScore(line1, line2, limits, epsilon = 20)
        nb_elements = line1.elements.length
        frames = []
        k = 0
        for f in 0..9
            balls = []

            if k < nb_elements
                e = line1.elements[k]
                if e.xmax < limits[f] - epsilon
                    if e.number == '/'
                        # this is for the one case the / appears in the middle at the 10th frame and the first ball was 0 ...
                        balls << "-"
                    end
                    balls << e.number
                    k += 1
                end

                if k < nb_elements
                    # Just in case we are in the 10th frame
                    e = line1.elements[k]
                    if e.xmax < limits[f] - epsilon
                        if balls.empty?
                            balls << "-"
                        end
                        balls << e.number
                        k += 1
                    end

                    if k < nb_elements
                        e = line1.elements[k]
                        if e.xmax < limits[f] + epsilon
                            if balls.empty? && e.number != "X"
                                balls << "-"
                            end
                            balls << e.number
                            k += 1
                        end
                    end
                end
            end

            while balls.length < 2 && balls[0] != 'X'
                balls << "-"
            end

            frames << {balls: balls, score: line2.elements[f].number.to_i}
        end
        return frames
    end

    def getScores(lines)
        # Score lines almost always have 2-digit numbers
        nb_players = 0
        index_first_player = 0
        n = lines.length
        for i in 0..(n-1)
            lines[i].elements.each do |e|
                if e.number.length > 1
                    nb_players += 1
                    if index_first_player == 0
                        index_first_player = i
                    end
                    break
                end
            end
        end

        # Now get the horizontal limits between frames
        limits = []
        lines[index_first_player].elements.each do |e|
            limits << e.xmax
        end

        # Finally organize the score in a JSON-like structure
        # Add the missing 0 score ball
        espilon = 20
        all_scores = []
        for i in 0..(nb_players-1)
            j = 2*i + index_first_player - 1
            frames = getScore(lines[j], lines[j+1], limits)
            all_scores << frames
        end

        return all_scores
    end

    def processImg(img)
        # OpenCV::cv::namedWindow("debug")
        resized = OpenCV::cv::Mat.new
        OpenCV::cv::resize(img, resized, OpenCV::cv::Size.new(2000, 1000))
        # OpenCV::cv::imshow("debug", resized)
        # OpenCV::cv::waitKey(10)
        bin = binarize(resized)
        # OpenCV::cv::imshow("debug", bin)
        # OpenCV::cv::waitKey(10)
        can = getCandidates(bin)
        r = getAverageRatio(can)
        can = prune(can, r)
        classifier = Ocr::Ocr.new('config/classifier.txt')
        canElement = []

        can.each_value do |c|
            vig = getVignette(c, r)
            number = classifier.predict(vig)
            next if number == 'None'
            number = "/" if number == "spare"
            b = OpenCV::cv::boundingRect(c[:external])
            canElement << Element.new(number, b.x, b.x + b.width, b.y, b.y + b.height)
        end

        lines = getLines(canElement)

        scores = getScores(lines)

        # lines.each do |l|
        #     l.elements.each do |e|
        #         print e.number, " "
        #     end
        #     puts " "
        # end

        return scores
    end
end
