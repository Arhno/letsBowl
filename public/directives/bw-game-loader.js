angular.module('bowling')
.directive('bwGameLoader', ['$http', function($http){
    return {
        restrict: "E",
        templateUrl: "/directives/bw-game-loader.html",
        scope: {
        },
        controller: function($scope){
            $scope.imgsrc = "";
            $scope.imgready = false;
        },
        link: function(scope, element){
            console.log(scope.imgsrc);
            input = element.find('.fileinput');
            input.on('change', function(e){
                var file = this.files[0];

                var reader = new FileReader();
                reader.addEventListener('load', function() {
                    scope.$apply(function(){
                        scope.imgsrc = reader.result;
                        scope.imgready = true;
                        $http.post(
                            '/api/v1/game_extracts',
                            {'image': reader.result},
                            {'headers': {
                                'content-type': 'application/json',
                                'accept': 'application/json'
                            }}
                        ).then(function(res){console.log(res.data) ; scope.score = res.data['score']});
                    });
                }, false);

                reader.readAsDataURL(file);
            });
        }
    }
}]);
