import 'dart:ui';
import 'package:flutter/material.dart';

void main() => runApp(const MetraApp());

const navy = Color(0xFF061B4A);
const blue = Color(0xFF087CF0);
const cyan = Color(0xFF37D6FF);
const pale = Color(0xFFEAF4FF);

class MetraApp extends StatelessWidget {
  const MetraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'METRA Weather Intelligence',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto', colorScheme: ColorScheme.fromSeed(seedColor: blue)),
    home: const WeatherHome(),
  );
}

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});
  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFFF2F6FF),
      body: Stack(children: [
        Container(height: 390, decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF061746), Color(0xFF0754B5), Color(0xFF62B8F6)]),
        )),
        SafeArea(child: CustomScrollView(slivers: [
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), sliver: SliverList(delegate: SliverChildListDelegate([
            Row(children: [
              Container(width: 48,height:48, decoration: BoxDecoration(color: Colors.white.withOpacity(.14),borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.cloudy_snowing,color: Colors.white,size:30)),
              const SizedBox(width:10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
                Text('METRA',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900,letterSpacing:1.2)),
                Text('Weather Intelligence',style:TextStyle(color:Color(0xFFBBD9FF),fontSize:11)),
              ])),
              _circleIcon(Icons.notifications_none),
              const SizedBox(width:8), _circleIcon(Icons.menu),
            ]),
            const SizedBox(height:26),
            Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('مرحباً بك 👋',style:TextStyle(color:Color(0xFFB9D7FF),fontSize:14)),
              SizedBox(height:5), Text('طقسك بذكاء',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.bold)),
            ])), Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(30),border:Border.all(color:Colors.white24)),child:const Row(children:[Icon(Icons.location_on,color:cyan,size:16),SizedBox(width:4),Text('الرياض',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),Icon(Icons.keyboard_arrow_down,color:Colors.white,size:17)]))]),
            const SizedBox(height:20),
            Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(colors:[Color(0xFF143B80),Color(0xFF0B2358)]),border:Border.all(color:Colors.white.withOpacity(.18)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.15),blurRadius:25,offset:const Offset(0,12))]),child:Column(children:[
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('الطقس الحالي',style:TextStyle(color:Color(0xFFC7DFFF))),Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:Colors.white.withOpacity(.1),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.more_horiz,color:Colors.white))]),
              const SizedBox(height:12),
              Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.wb_sunny_rounded,color:Color(0xFFFFD35A),size:72),const SizedBox(width:14),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('29°',style:TextStyle(color:Colors.white,fontSize:58,fontWeight:FontWeight.w300,height:1)),Text('غائم جزئياً',style:TextStyle(color:Color(0xFFD6E8FF),fontSize:16)),Text('العظمى 33°  •  الصغرى 21°',style:TextStyle(color:Color(0xFFB4D2FF,fontSize:11))])]),
              const SizedBox(height:15),
              const Divider(color:Colors.white24),
              const Row(children:[Expanded(child:_Metric(icon:Icons.water_drop_outlined,value:'62%',label:'الرطوبة')),Expanded(child:_Metric(icon:Icons.air,value:'12 km/h',label:'الرياح')),Expanded(child:_Metric(icon:Icons.visibility_outlined,value:'10 km',label:'الرؤية')),Expanded(child:_Metric(icon:Icons.speed,value:'1012',label:'الضغط hPa'))]),
            ])),
            const SizedBox(height:18),
            Row(children:[const Expanded(child:Text('توقعات الساعات القادمة',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Color(0xFF14264A)))),TextButton(onPressed:()=>setState(()=>tab=2),child:const Text('عرض الكل'))]),
            SizedBox(height:112,child:ListView(scrollDirection:Axis.horizontal,children:const [
              _HourCard(time:'الآن',icon:Icons.wb_sunny,temp:'29°',selected:true),_HourCard(time:'12 PM',icon:Icons.wb_sunny,temp:'30°'),_HourCard(time:'3 PM',icon:Icons.cloud_queue,temp:'33°'),_HourCard(time:'6 PM',icon:Icons.cloud,temp:'29°'),_HourCard(time:'9 PM',icon:Icons.nightlight_round,temp:'26°'),
            ])),
            const SizedBox(height:18),
            Row(children:[const Expanded(child:Text('مؤشرات الطقس',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Color(0xFF14264A)))),const Icon(Icons.tune,color:blue)]),
            const SizedBox(height:12),
            GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:11,crossAxisSpacing:11,childAspectRatio:1.55,children:const [
              _InfoTile(icon:Icons.thermostat,title:'درجة الحرارة',value:'29° C',sub:'شعور فعلي 31°',color:Color(0xFFFF9B43)),
              _InfoTile(icon:Icons.air,title:'سرعة الرياح',value:'12 km/h',sub:'شمالية غربية',color:Color(0xFF23B9D9)),
              _InfoTile(icon:Icons.water_drop,title:'الرطوبة',value:'62%',sub:'مستوى متوسط',color:Color(0xFF4388F6)),
              _InfoTile(icon:Icons.compress,title:'الضغط الجوي',value:'1012 hPa',sub:'مستقر',color:Color(0xFF8A70E8)),
            ]),
            const SizedBox(height:18),
            Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:navy.withOpacity(.05),blurRadius:18)]),child:Column(children:[
              Row(children:[const Expanded(child:Text('خريطة الطقس',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),TextButton(onPressed:()=>setState(()=>tab=1),child:const Text('فتح الخريطة'))]),
              Container(height:170,width:double.infinity,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFB9D9D7),Color(0xFF6FB6B5),Color(0xFFCEE0B0),Color(0xFF8DB8D5)])),child:Stack(children:[
                Positioned(left:-30,top:20,child:Transform.rotate(angle:-.35,child:Container(width:260,height:90,decoration:BoxDecoration(color:Colors.white.withOpacity(.25),borderRadius:BorderRadius.circular(100))))),
                Positioned(left:70,top:25,child:_mapPin(Colors.blue)),Positioned(right:80,top:70,child:_mapPin(Colors.green)),Positioned(left:160,bottom:25,child:_mapPin(Colors.deepPurple)),
                const Center(child:Icon(Icons.layers_outlined,color:Colors.white,size:38)),
                Positioned(right:12,bottom:12,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:Colors.white.withOpacity(.9),borderRadius:BorderRadius.circular(20)),child:const Text('رادار الطقس',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:navy)))),
              ])),
            ])),
            const SizedBox(height:18),
            Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFF102B66),Color(0xFF174DA0)])),child:const Row(children:[Icon(Icons.notifications_active_outlined,color:Color(0xFFFFD15C),size:30),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('التنبيهات الذكية',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16)),SizedBox(height:4),Text('ابقَ على اطلاع بتغيرات الطقس المهمة',style:TextStyle(color:Color(0xFFC4D9FF),fontSize:12))])),Icon(Icons.arrow_back_ios_new,color:Colors.white,size:17)])),
            const SizedBox(height:26),
          ]))),
        ])),
        Align(alignment:Alignment.bottomCenter,child:Container(decoration:BoxDecoration(color:Colors.white,borderRadius:const BorderRadius.vertical(top:Radius.circular(24)),boxShadow:[BoxShadow(color:navy.withOpacity(.08),blurRadius:20)]),child:NavigationBar(height:72,backgroundColor:Colors.transparent,selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [
          NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.map_outlined),selectedIcon:Icon(Icons.map),label:'الخريطة'),NavigationDestination(icon:Icon(Icons.analytics_outlined),selectedIcon:Icon(Icons.analytics),label:'التحليلات'),NavigationDestination(icon:Icon(Icons.notifications_none),selectedIcon:Icon(Icons.notifications),label:'التنبيهات'),NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'الإعدادات'),
        ]))),
      ]),
    ),
  );
}

Widget _circleIcon(IconData icon)=>Container(width:42,height:42,decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(15),border:Border.all(color:Colors.white24)),child:Icon(icon,color:Colors.white,size:21));
Widget _mapPin(Color color)=>Container(width:25,height:25,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(9),border:Border.all(color:Colors.white,width:2),boxShadow:[BoxShadow(color:color.withOpacity(.3),blurRadius:8)]),child:const Icon(Icons.location_on,color:Colors.white,size:15));

class _Metric extends StatelessWidget {
 const _Metric({required this.icon,required this.value,required this.label});
 final IconData icon;final String value,label;
 @override Widget build(BuildContext context)=>Column(children:[Icon(icon,color:cyan,size:20),const SizedBox(height:5),Text(value,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:13)),Text(label,style:const TextStyle(color:Color(0xFFB8D4FF),fontSize:10))]);
}
class _HourCard extends StatelessWidget {
 const _HourCard({required this.time,required this.icon,required this.temp,this.selected=false});
 final String time,temp;final IconData icon;final bool selected;
 @override Widget build(BuildContext context)=>Container(width:68,margin:const EdgeInsets.only(left:8),padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:selected?blue:Colors.white,borderRadius:BorderRadius.circular(19),boxShadow:selected?[]:[BoxShadow(color:navy.withOpacity(.04),blurRadius:8)]),child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(time,style:TextStyle(color:selected?Colors.white:const Color(0xFF71809A),fontSize:10)),Icon(icon,color:selected?const Color(0xFFFFD45C):blue,size:24),Text(temp,style:TextStyle(color:selected?Colors.white:navy,fontWeight:FontWeight.bold))]));
}
class _InfoTile extends StatelessWidget {
 const _InfoTile({required this.icon,required this.title,required this.value,required this.sub,required this.color});
 final IconData icon;final String title,value,sub;final Color color;
 @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:navy.withOpacity(.04),blurRadius:10)]),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Row(children:[Container(width:29,height:29,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:18)),const SizedBox(width:7),Expanded(child:Text(title,style:const TextStyle(fontSize:11,color:Color(0xFF75829A))))]),Text(value,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:navy)),Text(sub,style:const TextStyle(fontSize:9,color:Color(0xFF91A0B6)))]));
}
