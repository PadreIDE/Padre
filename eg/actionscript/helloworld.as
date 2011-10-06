package {
 import flash.display.*;
 import flash.text.*;
 public class HelloWorld extends Sprite {
   private var hello:TextField = new TextField();
   
   public function HelloWorld() {	  
     hello.text = "Hello World!";
     hello.x = 100;
     hello.y = 100;
     addChild(hello);
   }
 }
}